public class UdpSender {
    private Socket? socket = null;
    private InetSocketAddress? destination = null;
    private bool initialized = false;
    
    public UdpSender() {
        try {
            socket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            
            // Create address for 0.0.0.0:49161 instead of localhost
            uint8[] addr_bytes = { 0, 0, 0, 0 };
            var addr = new InetAddress.from_bytes(addr_bytes, SocketFamily.IPV4);
            destination = new InetSocketAddress(addr, 49161);
            
            initialized = true;
            print("UDP sender initialized (0.0.0.0:49161)\n");
        } catch (Error e) {
            warning("Failed to initialize UDP sender: %s", e.message);
        }
    }
    
    public bool send_message(string message) {
        if (!initialized || socket == null || destination == null) return false;
        
        try {
            size_t bytes_sent = socket.send_to(destination, message.data);
            print("UDP: Sent %lu bytes to 0.0.0.0:49161\n", bytes_sent);
            return true;
        } catch (Error e) {
            warning("UDP send error: %s", e.message);
            return false;
        }
    }
    
    public void cleanup() {
        if (initialized && socket != null) {
            try {
                socket.close();
            } catch (Error e) {
                warning("Error closing UDP socket: %s", e.message);
            }
        }
    }
}

public class NotePipeline {
    public Gst.Pipeline pipeline;
    public Gst.Element source;
    public uint timeout_id;
    public bool in_use;
    
    public NotePipeline() {
        try {
            print("Creating sound pipeline...\n");
            
            // Create a simple pipeline
            pipeline = new Gst.Pipeline("synth");
            source = Gst.ElementFactory.make("audiotestsrc", "source");
            var convert = Gst.ElementFactory.make("audioconvert", "convert");
            var sink = Gst.ElementFactory.make("autoaudiosink", "sink");
            
            if (pipeline == null || source == null || convert == null || sink == null) {
                warning("Failed to create GStreamer elements");
                return;
            }
            
            // Configure source - triangle wave
            source.set_property("wave", 0);
            source.set_property("volume", 0.0);
            
            // Add elements to pipeline
            pipeline.add(source);
            pipeline.add(convert);
            pipeline.add(sink);
            
            // Link elements
            source.link(convert);
            convert.link(sink);
            
            // Prepare pipeline (this can be done in advance)
            pipeline.set_state(Gst.State.READY);
            
            in_use = false;
            timeout_id = 0;
            print("Sound pipeline ready\n");
        } catch (Error e) {
            warning("Error creating pipeline: %s", e.message);
        }
    }
    
    public void cleanup() {
        if (timeout_id != 0) {
            Source.remove(timeout_id);
            timeout_id = 0;
        }
        
        source.set_property("volume", 0.0);
        pipeline.set_state(Gst.State.NULL);
        in_use = false;
    }
}

public class OrcaSynth {
    private List<NotePipeline> pipelines;
    private int frame_rate = 10;
    private int max_polyphony = 8; // Maximum simultaneous notes
    private bool initialized = false;

    private AlsaMidi midi;
    private string current_midi_output = "Synth";
    private HashTable<string, uint> active_notes; // track notes to stop them later
    private HashTable<int, uint> mono_active_notes; // Track active mono notes per channel
    
    private UdpSender udp_sender;
    
    // Visualization data
    private const int VIZ_BUFFER_SIZE = 16;
    private float[] amplitude_buffer;
    private int buffer_position = 0;
    
    public OrcaSynth() {
        pipelines = new List<NotePipeline>();
        
        // Pre-create pipelines for polyphony
        for (int i = 0; i < max_polyphony; i++) {
            pipelines.append(new NotePipeline());
        }
        
        // Initialize MIDI
        midi = new AlsaMidi();
        
        // Initialize note tracking
        active_notes = new HashTable<string, uint>(str_hash, str_equal);
        
        // Initialize mono note tracking
        mono_active_notes = new HashTable<int, uint>(int_hash, int_equal);
        
        // Initialize UDP sender
        udp_sender = new UdpSender();

        // Initialize visualization buffer
        amplitude_buffer = new float[VIZ_BUFFER_SIZE];
        for (int i = 0; i < VIZ_BUFFER_SIZE; i++) {
            amplitude_buffer[i] = 0.0f;
        }
        
        initialized = true;
        print("OrcaSynth initialized with %d voice polyphony\n", max_polyphony);
    }
    
    public void set_frame_rate(int fps) {
        frame_rate = fps;
    }
    
    public string[] get_midi_outputs() {
        return midi.get_output_names();
    }

    public string get_midi_output() {
        return current_midi_output;
    }

    public void set_midi_output(string output_name) {
        if (current_midi_output == output_name) {
            return;
        }
        
        print("Changing MIDI output to: %s\n", output_name);
        current_midi_output = output_name;
        midi.set_output(output_name);
    }
    
    // Frame counter for periodic fake amplitude data
    private int viz_frame_counter = 0;
    private bool debug_active = true;
    
    // Update visualization data each frame even when no notes are playing
    public void update_visualization() {
        // Apply decay to all amplitudes to simulate natural sound decay
        for (int i = 0; i < VIZ_BUFFER_SIZE; i++) {
            // Decay factor: reduce by about 3% per frame
            amplitude_buffer[i] *= 0.97f;
            
            // Ensure small values eventually reach zero
            if (amplitude_buffer[i] < 0.01f) {
                amplitude_buffer[i] = 0.0f;
            }
        }
    }

    // Get visualization data for display
    public void get_visualization_data(out float[] data, out int count) {
        data = new float[VIZ_BUFFER_SIZE];
        
        // Copy buffer starting from oldest data to newest
        // This ensures the most recent data appears at the right end of the visualization
        int start_pos = (buffer_position + 1) % VIZ_BUFFER_SIZE; // Start with oldest data
        
        for (int i = 0; i < VIZ_BUFFER_SIZE; i++) {
            int source_idx = (start_pos + i) % VIZ_BUFFER_SIZE;
            data[i] = amplitude_buffer[source_idx];
        }
        
        count = VIZ_BUFFER_SIZE;
    }
    
    private void add_amplitude(float amplitude) {
        // Ensure amplitude is in 0.0-1.0 range
        amplitude = (float)Math.fmin(1.0f, Math.fmax(0.0f, amplitude));
        
        // Add a small random variation to make visualization more interesting
        float variation = (float)((Random.next_double() - 0.5) * 0.15);
        
        // Add to buffer with variation but keep in valid range
        amplitude_buffer[buffer_position] = (float)Math.fmax(0.0f, Math.fmin(1.0f, amplitude + variation));
        
        // Update buffer position for next write
        buffer_position = (buffer_position + 1) % VIZ_BUFFER_SIZE;
    }

    // Map a character to a note and octave using the transpose mapping
    private void char_to_note_and_octave(char c, out int note_number, out int note_octave) {
        // Initialize with defaults
        note_number = 0;  // C
        note_octave = 4;  // Default to middle C (C4)
        
        // Parse according to the original transpose table
        switch (c) {
            // A notes (A-H-O-V sequence)
            case 'A': case 'H': note_number = 9; note_octave = 0; break; // A0
            case 'a': case 'h': note_number = 10; note_octave = 0; break; // A#0
            case 'O': note_number = 9; note_octave = 1; break; // A1
            case 'o': note_number = 10; note_octave = 1; break; // A#1
            case 'V': note_number = 9; note_octave = 2; break; // A2
            case 'v': note_number = 10; note_octave = 2; break; // A#2
            
            // B notes (B-I-P-W sequence)
            case 'B': case 'I': note_number = 11; note_octave = 0; break; // B0
            case 'P': note_number = 11; note_octave = 1; break; // B1
            case 'W': note_number = 11; note_octave = 2; break; // B2
            
            // C notes (C-J-Q-X sequence)
            case 'C': note_number = 0; note_octave = 0; break; // C0
            case 'c': note_number = 1; note_octave = 0; break; // C#0
            case 'J': note_number = 0; note_octave = 1; break; // C1
            case 'j': note_number = 1; note_octave = 1; break; // C#1
            case 'Q': note_number = 0; note_octave = 2; break; // C2
            case 'q': note_number = 1; note_octave = 2; break; // C#2
            case 'X': note_number = 0; note_octave = 3; break; // C3
            case 'x': note_number = 1; note_octave = 3; break; // C#3
            
            // D notes (D-K-R-Y sequence)
            case 'D': note_number = 2; note_octave = 0; break; // D0
            case 'd': note_number = 3; note_octave = 0; break; // D#0
            case 'K': note_number = 2; note_octave = 1; break; // D1
            case 'k': note_number = 3; note_octave = 1; break; // D#1
            case 'R': note_number = 2; note_octave = 2; break; // D2
            case 'r': note_number = 3; note_octave = 2; break; // D#2
            case 'Y': note_number = 2; note_octave = 3; break; // D3
            case 'y': note_number = 3; note_octave = 3; break; // D#3
            
            // E notes (E-L-S-Z sequence)
            case 'E': note_number = 4; note_octave = 0; break; // E0
            case 'L': note_number = 4; note_octave = 1; break; // E1
            case 'S': note_number = 4; note_octave = 2; break; // E2
            case 'Z': note_number = 4; note_octave = 3; break; // E3
            
            // F notes (F-M-T sequence + special 'e', 'l', 's', 'z' cases)
            case 'F': case 'e': note_number = 5; note_octave = 0; break; // F0
            case 'f': note_number = 6; note_octave = 0; break; // F#0
            case 'M': case 'l': note_number = 5; note_octave = 1; break; // F1
            case 'm': note_number = 6; note_octave = 1; break; // F#1
            case 'T': case 's': note_number = 5; note_octave = 2; break; // F2
            case 't': note_number = 6; note_octave = 2; break; // F#2
            case 'z': note_number = 5; note_octave = 3; break; // F3
            
            // G notes (G-N-U sequence)
            case 'G': note_number = 7; note_octave = 0; break; // G0
            case 'g': note_number = 8; note_octave = 0; break; // G#0
            case 'N': note_number = 7; note_octave = 1; break; // G1
            case 'n': note_number = 8; note_octave = 1; break; // G#1
            case 'U': note_number = 7; note_octave = 2; break; // G2
            case 'u': note_number = 8; note_octave = 2; break; // G#2
            
            // Special "Catch b" cases from JavaScript
            case 'b': note_number = 0; note_octave = 1; break; // C1
            case 'i': note_number = 0; note_octave = 1; break; // C1
            case 'p': note_number = 0; note_octave = 2; break; // C2
            case 'w': note_number = 0; note_octave = 3; break; // C3
        }
    }
    
    public void play_note(int channel, int octave_input, char note_char, int velocity, int duration_frames) {
        if (!initialized) {
            warning("Cannot play note - synth not initialized");
            return;
        }
        
        print("Playing note: %c\n", note_char);
        
        // Get note and octave from character
        int note_number;
        int note_octave;
        char_to_note_and_octave(note_char, out note_number, out note_octave);
        
        // Apply the octave_input as an offset
        int final_octave = note_octave + octave_input;
        
        // Calculate MIDI note number and frequency with correct offset
        int midi_note = (final_octave * 12) + note_number + 12;
        double frequency = 440.0 * Math.pow(2.0, (midi_note - 69.0) / 12.0);
        
        // Calculate duration in milliseconds based on frame rate
        int duration_ms = (duration_frames * 1000) / frame_rate;
        if (duration_ms < 50) duration_ms = 50; // Ensure minimum duration
        
        // Normalize velocity to range 0-127 for MIDI
        int midi_velocity = (velocity * 127) / 35;
        if (midi_velocity < 0) midi_velocity = 0;
        if (midi_velocity > 127) midi_velocity = 127;
        
        // Generate a unique identifier for this note
        string note_key = "%d-%d".printf(midi_note, Random.int_range(0, 1000000));
        
        // Is this MIDI output or internal synth?
        if (midi.get_current_output() != "Synth") {
            // Send MIDI note-on (use channel 0 by default)
            midi.send_note_on(0, midi_note, midi_velocity);
            
            // Schedule note-off
            uint timeout_id = Timeout.add(duration_ms, () => {
                midi.send_note_off(0, midi_note);
                active_notes.remove(note_key);
                return false;
            });
            
            active_notes.insert(note_key, timeout_id);
            
            // Update visualization data based on MIDI velocity
            double volume = Math.fmax(0.10, Math.fmin(0.5, (midi_velocity / 127.0) * 0.5));
            float viz_amplitude = (float)volume * 0.8f;
            add_amplitude(viz_amplitude);
            
            print("MIDI Note: %d, vel=%d, dur=%d ms\n", midi_note, midi_velocity, duration_ms);
        } else {
            // Use internal synth
            
            // Find an unused pipeline
            NotePipeline? note_pipeline = null;
            
            foreach (var pipeline in pipelines) {
                if (!pipeline.in_use) {
                    note_pipeline = pipeline;
                    break;
                }
            }
            
            if (note_pipeline == null) {
                // All pipelines in use, reuse the oldest one
                note_pipeline = pipelines.first().data;
                note_pipeline.cleanup();
            }
            
            note_pipeline.in_use = true;
            
            try {
                // Apply normalized velocity with a MINIMUM VOLUME to ensure sound is audible
                // Even with velocity 0, we'll use a minimum of 0.10 volume
                double volume = Math.fmax(0.10, Math.fmin(0.5, (velocity / 127.0) * 0.5));
                
                print("Synth: MIDI=%d, freq=%.2f Hz, duration=%d ms, volume=%.2f\n", 
                      midi_note, frequency, duration_ms, volume);
                
                // Set channel
                note_pipeline.source.set_property("wave", channel);
                
                // Set frequency
                note_pipeline.source.set_property("freq", frequency);
                
                // Reset pipeline state
                note_pipeline.pipeline.set_state(Gst.State.NULL);
                note_pipeline.pipeline.set_state(Gst.State.READY);
                
                // Set volume before playing to avoid race condition
                note_pipeline.source.set_property("volume", volume);
                
                // Start playback and don't wait for state change
                note_pipeline.pipeline.set_state(Gst.State.PLAYING);
                
                // Update visualization buffer with amplitude data
                float viz_amplitude = (float)volume * 0.8f;
                
                // Store the amplitude in the buffer
                add_amplitude(viz_amplitude);
                
                // Schedule note off
                if (note_pipeline.timeout_id != 0) {
                    Source.remove(note_pipeline.timeout_id);
                }
                
                note_pipeline.timeout_id = Timeout.add(duration_ms, () => {
                    print("Note duration complete, stopping\n");
                    
                    // Fade out gradually to avoid clicks
                    Timeout.add(10, () => {
                        note_pipeline.source.set_property("volume", 0.0);
                        return false;
                    });
                    
                    // Stop pipeline after fade
                    Timeout.add(30, () => {
                        note_pipeline.pipeline.set_state(Gst.State.NULL);
                        note_pipeline.in_use = false;
                        return false;
                    });
                    
                    note_pipeline.timeout_id = 0;
                    return false;
                });
            } catch (Error e) {
                warning("Error playing note: %s", e.message);
                note_pipeline.in_use = false;
            }
        }
    }

    // MIDI Control Change message
    public void send_midi_cc(int channel, int controller, int value) {
        if (channel < 0 || channel > 15) return;
        if (controller < 0 || controller > 127) return;
        if (value < 0 || value > 127) value = 0;
        
        print("Sending MIDI CC: ch=%d, ctrl=%d, val=%d\n", channel, controller, value);
        
        // Use ALSA MIDI to send control change
        if (midi != null && midi.get_current_output() != "Synth") {
            //midi.send_control_change(channel, controller, value);
        }
    }

    // MIDI Pitch Bend message
    public void send_midi_pitch_bend(int channel, int lsb, int msb) {
        if (channel < 0 || channel > 15) return;
        if (lsb < 0 || lsb > 127) lsb = 0;
        if (msb < 0 || msb > 127) msb = 64; // Default to middle position
        
        print("Sending MIDI Pitch Bend: ch=%d, lsb=%d, msb=%d\n", channel, lsb, msb);
        
        // Use ALSA MIDI to send pitch bend
        if (midi != null && midi.get_current_output() != "Synth") {
            //midi.send_pitch_bend(channel, lsb, msb);
        }
    }

    // Monophonic MIDI Note
    public void play_note_mono(int channel, int octave_input, char note_char, int velocity, int duration_frames) {
        if (!initialized) {
            warning("Cannot play note - synth not initialized");
            return;
        }
        
        // First, stop any active note on this channel
        stop_mono_note(channel);
        
        // Get note properties
        int note_number, note_octave;
        char_to_note_and_octave(note_char, out note_number, out note_octave);
        
        // Calculate MIDI note number with octave offset
        int final_octave = note_octave + octave_input;
        int midi_note = (final_octave * 12) + note_number + 12;
        
        // Calculate duration in milliseconds
        int duration_ms = (duration_frames * 1000) / frame_rate;
        if (duration_ms < 50) duration_ms = 50; // Ensure minimum duration
        
        print("Mono Note: ch=%d, midi=%d, vel=%d, dur=%d ms\n", 
              channel, midi_note, velocity, duration_ms);
        
        // Send MIDI note-on
        if (midi != null && midi.get_current_output() != "Synth") {
            midi.send_note_on(channel, midi_note, velocity);
            
            // Schedule note-off
            uint timeout_id = Timeout.add(duration_ms, () => {
                midi.send_note_off(channel, midi_note);
                mono_active_notes.remove(channel);
                return false;
            });
            
            // Store the timeout ID so we can cancel it if a new note comes in
            mono_active_notes.insert(channel, timeout_id);
        } else {
            // Use internal synth (same as regular note)
            play_note(channel, octave_input, note_char, velocity, duration_frames);
        }
    }

    // Helper method to stop any currently playing mono note
    private void stop_mono_note(int channel) {
        uint timeout_id = mono_active_notes.lookup(channel);
        if (timeout_id != 0) {
            // Cancel the scheduled note-off
            Source.remove(timeout_id);
            
            // If using MIDI, send an immediate note-off
            // We'd need to track the actual note number here
            if (midi != null && midi.get_current_output() != "Synth") {
                // In a complete implementation, we'd store the note number
                // midi.send_note_off(channel, stored_note_number);
            }
            
            mono_active_notes.remove(channel);
        }
    }

    // UDP message sending
    public void send_udp(string message) {
        udp_sender.send_message(message);
    }

    public void cleanup() {
        // Stop all active notes
        active_notes.foreach((key, timeout_id) => {
            Source.remove(timeout_id);
        });
        active_notes.remove_all();
        
        // Stop all mono notes
        mono_active_notes.foreach((channel, timeout_id) => {
            Source.remove(timeout_id);
        });
        mono_active_notes.remove_all();
        
        // Clean up MIDI
        midi.cleanup();
        
        // Clean up UDP
        udp_sender.cleanup();
        
        // Clean up existing pipelines
        foreach (var pipeline in pipelines) {
            pipeline.cleanup();
        }
    }
}

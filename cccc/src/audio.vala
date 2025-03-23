namespace App {
    /**
     * UxnAudio - Authentic Uxntal audio implementation for CCCC
     * 
     * Implements the exact waveform and ADSR envelope 
     * from the original Uxntal calculator code
     */
    public class UxnAudio : GLib.Object {
        // The 256-byte waveform data from the original Uxntal code
        private static uint8[] tone_data = {
            0x8e, 0xae, 0xb5, 0xb9, 0xc0, 0xce, 0xdb, 0xdc, 0xcd, 0xb6, 0xa2, 0x95, 0x8b, 0x80, 0x73, 0x64,
            0x59, 0x53, 0x52, 0x56, 0x58, 0x5a, 0x5d, 0x62, 0x68, 0x6f, 0x75, 0x79, 0x7d, 0x7e, 0x81, 0x83,
            0x85, 0x85, 0x84, 0x83, 0x85, 0x87, 0x8b, 0x96, 0x9d, 0x9e, 0x92, 0x82, 0x78, 0x76, 0x76, 0x74,
            0x70, 0x6b, 0x69, 0x6c, 0x74, 0x79, 0x7d, 0x81, 0x83, 0x85, 0x89, 0x8d, 0x8d, 0x8d, 0x8c, 0x8a,
            0x8a, 0x88, 0x86, 0x84, 0x81, 0x80, 0x7f, 0x7e, 0x7d, 0x7c, 0x7c, 0x7c, 0x7c, 0x7c, 0x7a, 0x74,
            0x64, 0x45, 0x22, 0x1d, 0x41, 0x79, 0xa2, 0xb4, 0xb7, 0xbc, 0xc7, 0xd6, 0xdd, 0xd5, 0xc0, 0xaa,
            0x9b, 0x8f, 0x86, 0x7a, 0x6b, 0x5e, 0x55, 0x53, 0x54, 0x56, 0x58, 0x5c, 0x60, 0x65, 0x6c, 0x73,
            0x78, 0x7c, 0x7e, 0x80, 0x82, 0x84, 0x84, 0x84, 0x84, 0x84, 0x85, 0x89, 0x91, 0x9a, 0xa0, 0x98,
            0x89, 0x7c, 0x76, 0x76, 0x75, 0x72, 0x6e, 0x6a, 0x6b, 0x6f, 0x77, 0x7d, 0x7f, 0x81, 0x85, 0x87,
            0x8c, 0x8e, 0x8e, 0x8d, 0x8c, 0x8a, 0x89, 0x88, 0x85, 0x84, 0x81, 0x7f, 0x7e, 0x7d, 0x7e, 0x7d,
            0x7c, 0x7d, 0x7c, 0x7c, 0x78, 0x6d, 0x55, 0x30, 0x1a, 0x2d, 0x5e, 0x91, 0xae, 0xb7, 0xb9, 0xc1,
            0xcf, 0xdc, 0xda, 0xcb, 0xb4, 0xa0, 0x94, 0x8b, 0x80, 0x72, 0x64, 0x58, 0x53, 0x54, 0x55, 0x58,
            0x5a, 0x5e, 0x63, 0x6a, 0x70, 0x76, 0x7a, 0x7d, 0x7f, 0x82, 0x84, 0x84, 0x85, 0x84, 0x84, 0x85,
            0x87, 0x8d, 0x96, 0x9e, 0x9d, 0x91, 0x81, 0x77, 0x75, 0x75, 0x74, 0x70, 0x6b, 0x69, 0x6c, 0x74,
            0x7a, 0x7e, 0x81, 0x82, 0x85, 0x89, 0x8d, 0x8e, 0x8e, 0x8d, 0x8a, 0x8a, 0x88, 0x87, 0x85, 0x82,
            0x80, 0x7e, 0x7e, 0x7d, 0x7c, 0x7c, 0x7c, 0x7c, 0x7d, 0x7b, 0x74, 0x63, 0x41, 0x21, 0x1e, 0x46
        };
        
        // Button-to-note frequency mapping from Uxntal
        // These are the frequencies produced by each key press in the original code
        private const double[] note_frequencies = {
            61.74,  // 0 - Note value 0x0b + 0x18 = 0x23 (35)
            65.41,  // 1 - Note value 0x0c + 0x18 = 0x24 (36)
            73.42,  // 2 - Note value 0x0e + 0x18 = 0x26 (38)
            82.41,  // 3 - Note value 0x10 + 0x18 = 0x28 (40)
            87.31,  // 4 - Note value 0x11 + 0x18 = 0x29 (41)
            98.00,  // 5 - Note value 0x13 + 0x18 = 0x2b (43)
            110.00, // 6 - Note value 0x15 + 0x18 = 0x2d (45)
            123.47, // 7 - Note value 0x17 + 0x18 = 0x2f (47)
            130.81, // 8 - Note value 0x18 + 0x18 = 0x30 (48)
            146.83, // 9 - Note value 0x1a + 0x18 = 0x32 (50)
            55.00,  // A - Note value 0x09 + 0x18 = 0x21 (33)
            49.00,  // B - Note value 0x07 + 0x18 = 0x1f (31)
            220.00, // C - Note value 0x21 + 0x18 = 0x39 (57)
            196.00, // D - Note value 0x1f + 0x18 = 0x37 (55)
            174.61, // E - Note value 0x1d + 0x18 = 0x35 (53)
            164.81  // F - Note value 0x1c + 0x18 = 0x34 (52)
        };
        
        // GStreamer pipeline for audio playback
        private Gst.Pipeline pipeline;
        private Gst.App.Src app_src;
        private Gst.Element volume_element;
        private bool initialized = false;
        private bool mute = false;
        
        // ADSR envelope settings from Uxntal (in samples)
        private int attack_samples;
        private int release_samples;
        
        // Volume control
        private double max_volume = 0.2;  // Maximum volume at 20% (user requested)
        
        /**
         * Create a new UxnAudio instance
         */
        public UxnAudio() {
            initialize();
        }
        
        /**
         * Initialize the GStreamer pipeline and audio settings
         */
        private void initialize() {
            if (initialized) return;
            
            try {
                // Create pipeline: appsrc -> audioconvert -> volume -> audioresample -> autoaudiosink
                pipeline = (Gst.Pipeline)Gst.parse_launch(
                    "appsrc name=src format=time ! audioconvert ! volume name=vol volume=0.2 ! audioresample ! autoaudiosink"
                );
                
                // Get the appsrc element
                app_src = (Gst.App.Src)pipeline.get_by_name("src");
                volume_element = pipeline.get_by_name("vol");
                
                // Configure appsrc
                app_src.caps = new Gst.Caps.simple(
                    "audio/x-raw",
                    "format", typeof(string), "U8",
                    "rate", typeof(int), 44100,
                    "channels", typeof(int), 1,
                    "layout", typeof(string), "interleaved"
                );
                
                app_src.format = Gst.Format.TIME;
                app_src.stream_type = Gst.App.StreamType.STREAM;
                
                // Set pipeline to ready state
                pipeline.set_state(Gst.State.READY);
                
                // Calculate ADSR samples at 44.1kHz sample rate
                // ADSR in Uxntal is #1006 (1/15s attack, 0 decay, 0 sustain, 6/15s release)
                int sample_rate = 44100;
                attack_samples = (int)(sample_rate / 15.0);         // 1/15 second attack (~67ms)
                release_samples = (int)((sample_rate * 6) / 15.0);  // 6/15 second release (~400ms)
                
                initialized = true;
            } catch (Error e) {
                warning("Failed to initialize UxnAudio: %s", e.message);
            }
        }
        
        /**
         * Set whether the audio is muted
         * 
         * @param value True to mute, false to unmute
         */
        public void set_mute(bool value) {
            mute = value;
        }
        
        /**
         * Play a note based on a calculator key value
         * 
         * @param key The key character (0-9, A-F) to play
         */
        public void play_note(string key) {
            if (!initialized || mute) return;
            
            try {
                // Reset pipeline state
                pipeline.set_state(Gst.State.NULL);
                pipeline.set_state(Gst.State.READY);
                
                // Figure out which note to play
                int index = -1;
                
                // Map key to note index
                switch (key.up()) {
                    case "0": index = 0; break;
                    case "1": index = 1; break;
                    case "2": index = 2; break;
                    case "3": index = 3; break;
                    case "4": index = 4; break;
                    case "5": index = 5; break;
                    case "6": index = 6; break;
                    case "7": index = 7; break;
                    case "8": index = 8; break;
                    case "9": index = 9; break;
                    case "A": index = 10; break;
                    case "B": index = 11; break;
                    case "C": index = 12; break;
                    case "D": index = 13; break;
                    case "E": index = 14; break;
                    case "F": index = 15; break;
                    default: return; // Invalid key
                }
                
                double frequency = note_frequencies[index];
                
                // Create the audio buffer with ADSR envelope
                create_and_play_note(frequency);
            } catch (Error e) {
                warning("Failed to play note: %s", e.message);
            }
        }
        
        /**
         * Create and play a note with the specified frequency
         * Uses the original Uxntal waveform with ADSR envelope
         * 
         * @param frequency The frequency of the note to play
         */
        private void create_and_play_note(double frequency) {
            int sample_rate = 44100;
            int total_samples = attack_samples + release_samples;
            
            uint8[] audio_data = new uint8[total_samples];
            
            // Calculate how many samples to advance in the waveform per output sample
            double sample_step = frequency * tone_data.length / sample_rate;
            double tone_pos = 0.0;
            
            // Apply ADSR envelope and fill the buffer
            for (int i = 0; i < total_samples; i++) {
                // Get sample from tone data with interpolation
                int pos_int = (int)tone_pos;
                double pos_frac = tone_pos - pos_int;
                uint8 sample1 = tone_data[pos_int % tone_data.length];
                uint8 sample2 = tone_data[(pos_int + 1) % tone_data.length];
                uint8 sample = (uint8)(sample1 * (1.0 - pos_frac) + sample2 * pos_frac);
                
                // Apply ADSR envelope
                double envelope;
                if (i < attack_samples) {
                    // Attack phase - linear ramp up
                    envelope = (double)i / attack_samples;
                } else {
                    // Release phase - linear ramp down
                    envelope = 1.0 - (double)(i - attack_samples) / release_samples;
                }
                envelope = double.min(1.0, double.max(0.0, envelope));
                
                // Apply envelope to sample and center around 128
                double processed = 128.0 + (sample - 128.0) * envelope;
                audio_data[i] = (uint8)processed;
                
                // Advance position in tone data
                tone_pos += sample_step;
                while (tone_pos >= tone_data.length) {
                    tone_pos -= tone_data.length;
                }
            }
            
            // Create a buffer and timestamp
            var buffer = new Gst.Buffer.wrapped(audio_data);
            buffer.duration = ((uint64)total_samples * Gst.SECOND) / sample_rate;
            
            // Set the volume
            volume_element.set_property("volume", max_volume);
            
            // Push buffer to pipeline
            pipeline.set_state(Gst.State.PLAYING);
            app_src.push_buffer(buffer);
            app_src.end_of_stream();
            
            // Connect a signal to reset the pipeline when playback ends
            var bus = pipeline.get_bus();
            bus.add_watch(GLib.Priority.DEFAULT, (bus, message) => {
                if (message.type == Gst.MessageType.EOS) {
                    Idle.add(() => {
                        pipeline.set_state(Gst.State.READY);
                        return false;
                    });
                }
                return true;
            });
        }
        
        /**
         * Set the maximum volume level (0.0-1.0)
         * 
         * @param volume Volume level between 0.0 and 1.0
         */
        public void set_volume(double volume) {
            // Clamp volume between 0.0 and 1.0
            max_volume = double.min(1.0, double.max(0.0, volume));
            
            // Update the volume element if it exists
            if (volume_element != null) {
                volume_element.set_property("volume", max_volume);
            }
        }
        
        /**
         * Clean up resources
         */
        public void cleanup() {
            if (pipeline != null) {
                pipeline.set_state(Gst.State.NULL);
            }
        }
    }
}
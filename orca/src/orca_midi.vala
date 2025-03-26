using Posix;

public interface MidiInterface {
    public abstract string[] get_output_names();
    public abstract void set_output(string name);
    public abstract string get_current_output();
    public abstract void send_note_on(int channel, int note, int velocity);
    public abstract void send_note_off(int channel, int note);
    public abstract void cleanup();
}

public class AlsaMidi : MidiInterface {
    private int midi_fd = -1;
    private bool alsa_available = false;
    private string current_output = "Synth";
    //private AlsaSeq seq;
    
    // List of MIDI outputs with corresponding device paths
    private struct MidiDevice {
        public string name;
        public string device_path;
    }
    
    private MidiDevice[] devices = {};
    
    public AlsaMidi() {
        // Always include internal synth
        devices += MidiDevice() {
            name = "Synth",
            device_path = ""
        };
        
        // Add virtual MIDI for testing (doesn't require hardware)
        devices += MidiDevice() {
            name = "Virtual MIDI",
            device_path = "virtual"
        };
        
        // Log available outputs
        print("Available MIDI outputs:\n");
        foreach (var device in devices) {
            print("  - %s\n", device.name);
        }
        
        // Try to get available hardware MIDI devices
        try {
            // Use GIO File API to scan directory
            File directory = File.new_for_path("/dev/snd");
            FileEnumerator enumerator = directory.enumerate_children(
                "standard::name", FileQueryInfoFlags.NONE);
                
            FileInfo file_info;
            while ((file_info = enumerator.next_file()) != null) {
                string name = file_info.get_name();
                
                if (name.has_prefix("midi")) {
                    string device_path = "/dev/snd/" + name;
                    
                    // Check if the device exists
                    if (FileUtils.test(device_path, FileTest.EXISTS)) {
                        // Add a user-friendly name for this device
                        string device_name = "MIDI: " + name.substring(4);
                        print("Found MIDI device: %s at %s\n", device_name, device_path);
                        
                        devices += MidiDevice() {
                            name = device_name,
                            device_path = device_path
                        };
                    }
                }
            }
            
            alsa_available = true;
            print("ALSA MIDI initialized with %d hardware devices\n", devices.length - 2);
        } catch (Error e) {
            warning("Failed to scan for MIDI devices: %s", e.message);
            alsa_available = false;
        }
    }
    
    public string[] get_output_names() {
        string[] names = {};
        
        foreach (var device in devices) {
            names += device.name;
        }
        
        return names;
    }
    
    public string get_current_output() {
        return current_output;
    }
    
    public void set_output(string name) {
        if (current_output == name) return;
        
        // Debug: print available outputs for comparison
        print("Setting MIDI output to: '%s'. Available options:\n", name);
        foreach (var device in devices) {
            print("  - '%s'\n", device.name);
        }
        
        // Close existing device if open
        if (midi_fd >= 0) {
            Posix.close(midi_fd);
            midi_fd = -1;
        }
        
        // Find the device
        foreach (var device in devices) {
            if (device.name == name) {
                current_output = name;
                
                // Skip connection for internal synth
                if (device.device_path == "") {
                    print("Using internal synth\n");
                    return;
                }
                
                // Handle virtual MIDI
                if (device.device_path == "virtual") {
                    print("Using Virtual MIDI output (debug mode)\n");
                    midi_fd = -999; // Special marker for virtual
                    return;
                }
                
                // Try to open the device
                midi_fd = Posix.open(device.device_path, Posix.O_WRONLY);
                
                if (midi_fd < 0) {
                    warning("Failed to open MIDI device: %s", Posix.strerror(Posix.errno));
                } else {
                    print("Connected to MIDI device: %s\n", name);
                }
                
                return;
            }
        }
        
        warning("MIDI output '%s' not found", name);
    }
    
    public void send_note_on(int channel, int note, int velocity) {
        // Skip internal synth
        if (current_output == "Synth") {
            return;
        }
        
        // Handle virtual MIDI
        if (midi_fd == -999) {
            print("VIRTUAL MIDI: Note On | Channel: %d | Note: %d | Velocity: %d\n", 
                  channel, note, velocity);
            return;
        }
        
        // Regular hardware handling
        if (midi_fd < 0) {
            return;
        }
        
        // Create a standard MIDI note-on message
        uint8[] message = new uint8[3];
        message[0] = (uint8)(0x90 | (channel & 0x0F)); // Note On message
        message[1] = (uint8)(note & 0x7F);
        message[2] = (uint8)(velocity & 0x7F);
        
        // Write to the MIDI device
        ssize_t result = Posix.write(midi_fd, message, 3);
        if (result != 3) {
            warning("Failed to write MIDI note-on message");
        }
    }
    
    public void send_note_off(int channel, int note) {
        // Skip internal synth
        if (current_output == "Synth") {
            return;
        }
        
        // Handle virtual MIDI
        if (midi_fd == -999) {
            print("VIRTUAL MIDI: Note Off | Channel: %d | Note: %d\n", 
                  channel, note);
            return;
        }
        
        // Regular hardware handling
        if (midi_fd < 0) {
            return;
        }
        
        // Create a standard MIDI note-off message
        uint8[] message = new uint8[3];
        message[0] = (uint8)(0x80 | (channel & 0x0F)); // Note Off message
        message[1] = (uint8)(note & 0x7F);
        message[2] = 0; // Velocity of 0
        
        // Write to the MIDI device
        ssize_t result = Posix.write(midi_fd, message, 3);
        if (result != 3) {
            warning("Failed to write MIDI note-off message");
        }
    }
    
    public void cleanup() {
        if (midi_fd >= 0 && midi_fd != -999) {
            Posix.close(midi_fd);
            midi_fd = -1;
        }
    }
}
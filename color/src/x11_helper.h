#include <sys/time.h>  // for gettimeofday
#include <unistd.h>    // for usleep

#ifndef X11_HELPER_H
#define X11_HELPER_H

// Structure to hold RGB values - using a unique name to avoid conflicts
typedef struct {
    unsigned char r;
    unsigned char g;
    unsigned char b;
} X11RGBColor;

// Initialize X display and return a pointer to it
void* x11_init_display();

// Close the X display
void x11_close_display(void* display);

// Get the root window
unsigned long x11_get_root_window(void* display);

// Check if the left mouse button is pressed
// Returns: 1 if pressed, 0 if not, -1 on error
int x11_is_button1_pressed(void* display, unsigned long root_window, int* x_pos, int* y_pos);

// Get color at position
// Returns: 1 on success, 0 on failure
int x11_get_pixel_color(void* display, unsigned long root_window, int x, int y, X11RGBColor* color);

// Wait for a mouse click and get the position
// Returns: 1 if click happened, 0 if timeout/error
int x11_wait_for_click(void* display, unsigned long root_window, 
                      int timeout_ms, int* x_pos, int* y_pos);

// Grab the pointer to receive events from anywhere on the screen
// Returns: 1 on success, 0 on failure
int x11_grab_pointer(void* display, unsigned long root_window);

// Ungrab the pointer
void x11_ungrab_pointer(void* display);

#endif /* X11_HELPER_H */
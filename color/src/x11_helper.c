#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdio.h>
#include <stdlib.h>
#include "x11_helper.h"

// Initialize X display and return a pointer to it
void* x11_init_display() {
    return (void*)XOpenDisplay(NULL);
}

// Close the X display
void x11_close_display(void* display) {
    if (display) {
        XCloseDisplay((Display*)display);
    }
}

// Get the root window
unsigned long x11_get_root_window(void* display) {
    if (!display) return 0;
    return DefaultRootWindow((Display*)display);
}

// Check if the left mouse button is pressed
// Returns: 1 if pressed, 0 if not, -1 on error
int x11_is_button1_pressed(void* display, unsigned long root_window, int* x_pos, int* y_pos) {
    if (!display || root_window == 0) return -1;
    
    Window root_return, child_return;
    int root_x, root_y;
    int win_x, win_y;
    unsigned int mask;
    
    int result = XQueryPointer(
        (Display*)display,
        root_window,
        &root_return,
        &child_return,
        &root_x,
        &root_y,
        &win_x,
        &win_y,
        &mask
    );
    
    if (result) {
        // Set output parameters
        if (x_pos) *x_pos = root_x;
        if (y_pos) *y_pos = root_y;
        
        // Check for Button1Mask (256)
        return (mask & 256) ? 1 : 0;
    }
    
    return -1;
}

// Get color at position
// Returns: 1 on success, 0 on failure
int x11_get_pixel_color(void* display, unsigned long root_window, int x, int y, X11RGBColor* color) {
    if (!display || root_window == 0 || !color) return 0;
    
    XImage* image = XGetImage(
        (Display*)display,
        root_window,
        x, y,
        1, 1,
        AllPlanes,
        ZPixmap
    );
    
    if (!image) return 0;
    
    unsigned long pixel = XGetPixel(image, 0, 0);
    
    // Extract RGB components
    color->r = (pixel & 0x00ff0000) >> 16;
    color->g = (pixel & 0x0000ff00) >> 8;
    color->b = (pixel & 0x000000ff);
    
    XDestroyImage(image);
    
    return 1;
}

// Grab the pointer to receive events from anywhere on the screen
// Returns: 1 on success, 0 on failure
int x11_grab_pointer(void* display, unsigned long root_window) {
    if (!display || root_window == 0) return 0;
    
    // Create a special cursor for color picking
    Cursor cursor = XCreateFontCursor((Display*)display, 34); // XC_crosshair
    
    int result = XGrabPointer(
        (Display*)display,
        root_window,
        False,                      // owner_events
        ButtonPressMask,            // event_mask
        GrabModeAsync,              // pointer_mode
        GrabModeAsync,              // keyboard_mode
        None,                       // confine_to
        cursor,                     // cursor
        CurrentTime
    );
    
    if (result != GrabSuccess) {
        fprintf(stderr, "Failed to grab pointer: %d\n", result);
        return 0;
    }
    
    // Make sure events are processed
    XFlush((Display*)display);
    return 1;
}

// Ungrab the pointer
void x11_ungrab_pointer(void* display) {
    if (!display) return;
    
    XUngrabPointer((Display*)display, CurrentTime);
    XFlush((Display*)display);
}

// Wait for a mouse click and get the position
// Returns: 1 if click happened, 0 if timeout/error
int x11_wait_for_click(void* display, unsigned long root_window, 
                      int timeout_ms, int* x_pos, int* y_pos) {
    if (!display || root_window == 0) return 0;
    
    Display* d = (Display*)display;
    XEvent event;
    int got_event = 0;
    
    // Set a timeout
    struct timeval start_time, current_time;
    gettimeofday(&start_time, NULL);
    
    while (!got_event) {
        // Check for timeout
        gettimeofday(&current_time, NULL);
        long elapsed = (current_time.tv_sec - start_time.tv_sec) * 1000 + 
                       (current_time.tv_usec - start_time.tv_usec) / 1000;
        if (elapsed > timeout_ms) {
            fprintf(stderr, "Timeout waiting for click\n");
            return 0;
        }
        
        // Check for events
        if (XPending(d) > 0) {
            XNextEvent(d, &event);
            if (event.type == ButtonPress) {
                if (x_pos) *x_pos = event.xbutton.x_root;
                if (y_pos) *y_pos = event.xbutton.y_root;
                got_event = 1;
                break;
            }
        }
        
        // Sleep a bit to avoid using 100% CPU
        usleep(10000); // 10ms
    }
    
    return got_event;
}
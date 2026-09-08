#include "SDL_internal.h"
#include "events/SDL_keyboard_c.h"
#include "events/SDL_mouse_c.h"

// Use SDL's input path so both queued events and polled state stay consistent.
DECLSPEC void FPIKeyboard(int scan, int down) {
    SDL_SendKeyboardKey(down ? SDL_PRESSED : SDL_RELEASED, (SDL_Scancode)scan);
}
DECLSPEC void FPIText(const char *text) {
    if (SDL_IsTextInputActive()) SDL_SendKeyboardText(text);
}
static SDL_Window *inputWindow(void) {
    SDL_Window *window=SDL_GetMouseFocus();
    return window ? window : SDL_GetKeyboardFocus();
}
DECLSPEC void FPIMouseButton(int button, int down) {
    SDL_SendMouseButton(inputWindow(),0,down ? SDL_PRESSED : SDL_RELEASED,(Uint8)button);
}
DECLSPEC void FPIWheel(float y) {
    SDL_SendMouseWheel(inputWindow(),0,0,y,SDL_MOUSEWHEEL_NORMAL);
}
DECLSPEC void FPIPointer(float x,float y) {
    SDL_Window *window=inputWindow();
    if (!window) return;
    int width,height; SDL_GetWindowSize(window,&width,&height);
    SDL_SendMouseMotion(window,0,0,(int)(x*width),(int)(y*height));
}
DECLSPEC int FPIGetPointer(float *x,float *y) {
    SDL_Window *window=inputWindow();
    if (!window) return 0;
    int width,height,mouseX,mouseY;
    SDL_GetWindowSize(window,&width,&height);
    if (width<=0 || height<=0) return 0;
    SDL_GetMouseState(&mouseX,&mouseY);
    *x=(float)mouseX/width; *y=(float)mouseY/height;
    return 1;
}

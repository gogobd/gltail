/*
 * Force-included (clang -include) by bin/setup when the `glut` gem is built
 * against Apple's GLUT.framework on macOS.
 *
 * glut 8.3.0's ext/glut/glut_ext.c unconditionally binds eight freeglut-only
 * functions. Apple's GLUT has none of them, so modern clang refuses to compile
 * the gem ("call to undeclared function"). glTail never calls any of these,
 * so they are provided here as local stand-ins: glutMainLoopEvent maps to
 * Apple's equivalent (glutCheckLoop); the rest are no-ops.
 *
 * Skipped when a real freeglut header is visible, since the gem's extconf
 * prefers <GL/freeglut.h> and freeglut declares the real functions.
 */
#ifndef GLTAIL_GLUT_MACOS_COMPAT_H
#define GLTAIL_GLUT_MACOS_COMPAT_H

#if defined(__APPLE__) && !__has_include(<GL/freeglut.h>)

extern void glutCheckLoop(void);

static inline void glutMainLoopEvent(void) { glutCheckLoop(); }
static inline void glutLeaveMainLoop(void) {}
static inline void glutExit(void) {}
static inline void glutFullScreenToggle(void) {}
static inline void glutLeaveFullScreen(void) {}
static inline void glutInitContextVersion(int major, int minor) { (void)major; (void)minor; }
static inline void glutInitContextFlags(int flags) { (void)flags; }
static inline void glutInitContextProfile(int profile) { (void)profile; }

#endif

#endif /* GLTAIL_GLUT_MACOS_COMPAT_H */

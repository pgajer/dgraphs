#ifndef GFLOW_MACROS_H
#define GFLOW_MACROS_H

#include <R.h>
#include <Rinternals.h>

/*!
 * \file gflow_macros.h
 * \brief Common macros for error handling and debugging in the gflow package
 */

/*!
 * \def CHECK_PTR(p)
 * \brief Check if a pointer is NULL and throw an R error if it is
 *
 * This macro tests a pointer for NULL value and calls R's error() function
 * if the pointer is NULL, which will properly unwind the R call stack.
 *
 * \param p A pointer to check
 *
 * \note Uses do-while(0) idiom to ensure proper behavior in all contexts
 */
#define CHECK_PTR(p) \
    do { \
        if ((p) == NULL) { \
            Rf_error("Memory allocation failed in file %s at line %d.\n", __FILE__, __LINE__); \
        } \
    } while(0)

/*!
 * \def CHECK_INTERRUPT()
 * \brief Check for user interruption (Ctrl+C) in long-running operations
 */
#define CHECK_INTERRUPT() \
    do { \
        R_CheckUserInterrupt(); \
    } while(0)

/*!
 * \def ASSERT_BOUNDS(index, size)
 * \brief Assert that an index is within valid bounds
 * \param index The index to check
 * \param size The size of the container
 */
#define ASSERT_BOUNDS(index, size) \
    do { \
        if ((index) < 0 || (index) >= (size)) { \
            Rf_error("Index out of bounds: %d not in [0, %d) at %s:%d\n", \
                  (index), (size), __FILE__, __LINE__); \
        } \
    } while(0)

/*!
 * \def DEBUG_PRINT(fmt, ...)
 * \brief Print debug messages when DEBUG is defined
 * \param fmt Printf-style format string
 * \param ... Arguments for the format string
 */
#ifdef DEBUG
    #define DEBUG_PRINT(fmt, ...) \
        do { \
            Rprintf("[DEBUG] %s:%d: " fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__); \
        } while(0)
#else
    #define DEBUG_PRINT(fmt, ...) do {} while(0)
#endif

/*!
 * \def SAFE_FREE(p)
 * \brief Safely free memory and set pointer to NULL
 * \param p Pointer to free
 */
#define SAFE_FREE(p) \
    do { \
        if ((p) != NULL) { \
            Free(p); \
            (p) = NULL; \
        } \
    } while(0)

#endif /* GFLOW_MACROS_H */

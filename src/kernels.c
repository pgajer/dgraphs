#include <R.h>
#include <Rinternals.h>
#include <Rmath.h>
#include <math.h>
#include <float.h>

#include "kernels.h"

static double g_scale = 1.0;  // Global scale parameter used by both normal and Laplace kernels
void (*kernel_fn)(const double*, int, double*);  // Actual definition of the function pointer

/*!
 * @brief Normal kernel wrapper using global scale parameter.
 *
 * Computes (sqrt(2/π)/scale) * exp(-x^2/(2*scale^2)) for each input value.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
static void normal_kernel_wrapper(const double *x, int n, double *w) {
    double norm_factor = 0.3989423;
    double inv_scale = 1.0 / g_scale;
    double scaling = norm_factor * inv_scale;

    for (int i = 0; i < n; i++) {
        double scaled_x = x[i] * inv_scale;
        w[i] = scaling * exp(-scaled_x * scaled_x / 2);
    }
}


/*!
 * @brief Laplace kernel wrapper using global scale parameter.
 *
 * Computes exp(-|x/scale|) for each input value.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
static void laplace_kernel_wrapper(const double *x, int n, double *w) {
  const double norm_factor = 0.5;
    double inv_scale = 1.0 / g_scale;
    double scaling = norm_factor * inv_scale;

    for (int i = 0; i < n; i++) {
        w[i] = scaling * exp(-fabs(x[i] * inv_scale));
    }
}

/*!
 * @brief Initialize the kernel function to be used for smoothing.
 *
 * This function sets up the global kernel function pointer based on the specified kernel type.
 * For Normal and Laplace kernels, it also handles scaling:
 * - When scale = 1.0, uses the standard kernel implementation
 * - When scale != 1.0, uses a wrapper implementation that applies the scale factor:
 *   - For Normal kernel: w = (sqrt(2/pi)/scale) * exp(-0.5 * (x/scale)^2)
 *   - For Laplace kernel: w = exp(-|x/scale|)
 * - For all other kernels, the scale parameter is ignored
 *
 * @param ikernel The type of kernel to use (EPANECHNIKOV, TRIANGULAR, etc.)
 * @param scale Scale parameter for Normal and Laplace kernels (default = 1.0)
 *
 * @throws Error if an unknown kernel type is specified
 */
void initialize_kernel(int ikernel, double scale) {
  switch (ikernel) {
  case EPANECHNIKOV:
    kernel_fn = epanechnikov_kernel;
    break;
  case TRIANGULAR:
    kernel_fn = triangular_kernel;
    break;
  case TREXPONENTIAL:
    kernel_fn = tr_exponential_kernel;
    break;
  case LAPLACE:
    if (scale != 1.0) {
      g_scale = scale;
      kernel_fn = laplace_kernel_wrapper;
    } else {
      kernel_fn = laplace_kernel;
    }
    break;
  case NORMAL:
    if (scale != 1.0) {
      g_scale = scale;
      kernel_fn = normal_kernel_wrapper;
    } else {
      kernel_fn = normal_kernel;
    }
    break;
  case BIWEIGHT:
    kernel_fn = biweight_kernel;
    break;
  case TRICUBE:
    kernel_fn = tricube_kernel;
    break;
  case COSINE:
    kernel_fn = cosine_kernel;
    break;
  case HYPERBOLIC:
    kernel_fn = hyperbolic_kernel;
    break;
  case CONSTANT:
    kernel_fn = const_kernel;
    break;
  default:
    Rf_error("In %s line %d: initialize_kernel(): ikernel=%d: Unknown kernel in the internal C function",
             __FILE__, __LINE__, ikernel);
  }
}

/*!
 * @brief Evaluates a kernel specified by kernel index over a numeric vector.
 *
 * This calls initialize_kernel() to set the correct kernel function pointer
 * and then applies it to the input data.
 *
 * @param ikernel - kernel index
 * @param x       - input 1D array
 * @param n       - number of elements of x
 * @param y       - output 1D array
 * @param scale   - optional scale parameter (default = 1.0)
 */
void C_kernel_eval(const int* ikernel,
                   const double* x,
                   const int* n,
                   double* y,
                   const double* scale)
{
    initialize_kernel(*ikernel, *scale);
    kernel_fn(x, *n, y);
}

//
// The following kernel definitions return void and assume that the output is
// passed to the w argument that already has memory allocated by the user.
//

/*!
 * @brief Constant function equal to 1 for all x.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void const_kernel(const double* x, int n, double *w) {
    for (int i=0; i<n; i++)
        w[i] = 1;
}

/*!
 * @brief Triangular kernel function equal to 1 - |x| within [-1, 1] and 0 otherwise.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void triangular_kernel(const double *x, int n, double *w) {
    double t;
    for (int i=0; i<n; i++) {
      t = fabs(x[i]);
      if ( t < 1 )
        w[i] = 1 - t;
      else
        w[i] = 0;
    }
}

/*!
 * @brief Epanechnikov kernel function equal to 1 - x^2 within [-1, 1] and 0 otherwise.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void epanechnikov_kernel(const double *x, int n, double *w)
{
    double t;
    for ( int i = 0; i < n; i++) {
      t = fabs(x[i]);
      if ( t < 1 )
        w[i] = 1 - t*t;
      else
        w[i] = 0;
    }
}

/*!
 * @brief Truncated exponential kernel function equal to (1-|x|)exp(-|x|) within [-1, 1] and 0 otherwise.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void tr_exponential_kernel(const double *x, int n, double *w)
{
    double t;
    for ( int i=0; i<n; i++ ) {
      t = fabs(x[i]);
      if ( t < 1 )
        w[i] = (1 - t)*exp(-t);
      else
        w[i] = 0;
    }
}

/*!
 * @brief Quartic (Biweight) kernel function equal to (1 - x^2)^2 within [-1, 1] and 0 otherwise.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void biweight_kernel(const double *x, int n, double *w) {
    double t;
    for (int i = 0; i < n; i++) {
        t = fabs(x[i]);
        if (t < 1)
            w[i] = pow(1 - t*t, 2);
        else
            w[i] = 0;
    }
}

/*!
 * @brief Tricube kernel function equal to (1 - |x|^3)^3 within [-1, 1] and 0 otherwise.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void tricube_kernel(const double *x, int n, double *w) {
    double t;
    for (int i = 0; i < n; i++) {
        t = fabs(x[i]);
        if (t < 1)
            w[i] = pow(1 - pow(t, 3), 3);
        else
            w[i] = 0;
    }
}

/*!
 * @brief Cosine kernel function equal to cos(πx/2) within [-1, 1] and 0 otherwise.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void cosine_kernel(const double *x, int n, double *w) {
    double t;
    for (int i = 0; i < n; i++) {
        t = fabs(x[i]);
        if (t < 1)
            w[i] = cos(M_PI * t / 2);
        else
            w[i] = 0;
    }
}

/*!
 * @brief Density function of normal absolute errors, where X ~ N(0,1).
 *
 * Computes sqrt(2/π) * exp(-x^2/2) for each input value.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void normal_kernel(const double *x, int n, double* w)
{
    double scaling = 0.3989423; // The normalizing constant for the density of normal absolute errors equal to sqrt(1/(2*pi)).
    for ( int i = 0; i < n; i++ )
      w[i] = scaling * exp(-x[i]*x[i]/2);
}

/*!
 * @brief Standard Laplace kernel with scale = 1.
 *
 * Computes exp(-|x|) for each input value.
 *
 * @param x An input double array.
 * @param n The number of elements of x.
 * @param w An output array of kernel values (weights).
 */
inline void laplace_kernel(const double *x, int n, double *w) {
  const double norm_factor = 0.5;
    for (int i = 0; i < n; i++) {
        w[i] = norm_factor * exp(-fabs(x[i]));
    }
}


/*!
 * @brief Computes hyperbolic (1/|x|) kernel weights with special handling for x=0.
 *
 * @details This function implements a hyperbolic kernel that assigns weights inversely
 * proportional to the absolute value of each input. For x=0, it assigns the maximum
 * possible double value to maintain continuity while avoiding division by zero.
 *
 * The kernel is particularly suitable for computing weights based on goodness of fit
 * measures or other strictly positive metrics, where x=0 represents perfect fit
 * and should receive maximum weight.
 *
 * The general formula is:
 * \f[
 *    w(x) = \begin{cases}
 *    \frac{1}{|x|} & \text{if } x \neq 0 \\
 *    \text{DBL\_MAX} & \text{if } x = 0
 *    \end{cases}
 * \f]
 *
 * @param x Pointer to array of input values
 * @param n Number of elements in x array
 * @param w Pointer to array where weights will be stored
 *
 * @note The function assumes both pointers are valid and point to arrays of at least n elements
 * @Rf_warning Care should be taken when using the weights from x=0 cases in subsequent calculations
 *          due to their extremely large values
 *
 * @see DBL_MAX from <float.h> for the maximum value used in x=0 case
 */
inline void hyperbolic_kernel(const double *x, int n, double *w) {
    for (int i = 0; i < n; i++) {
        w[i] = (x[i] != 0) ? 1.0 / fabs(x[i]) : DBL_MAX;
    }
}



// ---------------------------------------------------
//
//    Kernel functions with stop and bw parameters
//
// ---------------------------------------------------

/*!
    \fn void C_triangular_kernel_with_stop(double *x, int *rn, int *stop, double *bw, double *w)

    \brief Triangular kernel function equal to 1 - fabs(x) within [-1, 1] and 0 otherwise.

    This version is suited for the input that is sorted (in the increasing
    order) so the values of kernel are decreeasing. Kernel evaluation stops when
    the first 0 value is encountered. This index of the first 0 value is passed
    to variable 'stop'.

    \param x     An input double array.
    \param rn    A reference to the number of elements of x.
    \param rbw   A reference to a bandwidth.

    \param stop  An output pointer to the first element with the value of the kernel on that element equal to 0.
    \param w     An output array of kernel values (weights).

*/
inline void C_triangular_kernel_with_stop(const double *x, const int *rn, const double *rbw, int *stop, double *w)
{
    int n = rn[0];
    double bw = rbw[0];

    double t;
    for ( int i = 0; i < n; i++ ) {
      t = fabs(x[i] / bw);
      if ( t < 1 ){
        w[i] = 1 - t;
      } else {
        w[i] = 0;
        *stop = i - 1;
        break;
      }
    }
}

/*!
    \fn void C_epanechnikov_kernel_with_stop(double *x, int n, int *stop, double *w)

    \brief Epanechnikov kernel function equal to 1 - t^2 within [-1, 1] and 0
    otherwise; t = abs(x/bw).

    This version is suited for the input that is sorted (in the increasing
    order) so the values of kernel are decreeasing. Kernel evaluation stops when
    the first 0 value is encountered. This index of the first 0 value is passed
    to variable 'stop'.

    \param x     An input double array.
    \param rn    A reference to the number of elements of x.
    \param rbw   A reference to a bandwidth.

    \param stop  An output pointer to the last non-zero weight element of w.
    \param w     An output array of kernel values (weights).

*/
inline void C_epanechnikov_kernel_with_stop(const double *x,
                                            const int *rn,
                                            const double *rbw,
                                            int *stop,
                                            double *w)
{
    int n     = rn[0];
    double bw = rbw[0];

    double t;
    for ( int i = 0; i < n; i++) {
      t = fabs(x[i] / bw);
      if ( t < 1 ){
        w[i] = 1 - t*t;
      } else {
        w[i] = 0;
        *stop = i - 1; // index of the last element with a non-zero weight
        break;
      }
    }
}

/*!
    \fn void C_tr_exponential_kernel_with_stop(double *x, int n, int *stop, double *w)

    \brief Truncated exponential kernel function equal to (1-t)*exp(-t) for within [-1, 1] and 0 otherwise; t = abs(x)

    This version is suited for the input that is sorted (in the increasing
    order) so the values of kernel are decreeasing. Kernel evaluation stops when
    the first 0 value is encountered. This index of the first 0 value is passed
    to variable 'stop'.

    \param x     An input double array.
    \param rn    A reference to the number of elements of x.
    \param rbw   A reference to a bandwidth.

    \param stop  An output pointer to the first element with the value of the kernel on that element equal to 0.
    \param w     An output array of kernel values (weights).

*/
inline void C_tr_exponential_kernel_with_stop(const double *x, const int *rn, const double *rbw, int *stop, double *y)
{
    int n = rn[0];
    double bw = rbw[0];

    double t;
    for ( int i=0; i<n; i++ ) {
      t = fabs(x[i] / bw);
      if ( t < 1 ){
        y[i] = (1 - t)*exp(-t);
      } else {
        y[i] = 0;
        *stop = i - 1; // index of the last element with a non-zero weight
        break;
      }
    }
}

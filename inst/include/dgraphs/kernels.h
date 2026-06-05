#ifndef MSR2_KERNELS_H_
#define MSR2_KERNELS_H_

/* Kernel Indices */
#define EPANECHNIKOV 1
#define TRIANGULAR 2
#define TREXPONENTIAL 3
#define LAPLACE 4
#define NORMAL 5
#define BIWEIGHT 6
#define TRICUBE 7
#define COSINE 8
#define HYPERBOLIC 9
#define CONSTANT 10

/* Kernel Total Masses (2∫₀¹ K(x)dx)
 * These values represent the total mass of each kernel function
 * over [-1,1], computed as 2∫₀¹ K(x)dx using symmetry.
 *
 * Analytic values:
 * - TRIANGULAR: 1.0 (∫(1-|x|)dx = 1)
 * - EPANECHNIKOV: 4/3 (∫(1-x²)dx = 4/3)
 * - BIWEIGHT: 5/7 (∫(1-x²)²dx = 5/7)
 *
 * Numerically computed values (to high precision):
 * - TREXPONENTIAL: ∫(1-|x|)exp(-|x|)dx ≈ 0.632121
 * - LAPLACE: ∫exp(-|x|)dx ≈ 0.632121
 * - NORMAL: sqrt(2/π) ≈ 0.797885
 * - TRICUBE: ∫(1-|x|³)³dx ≈ 0.857143
 * - COSINE: ∫cos(πx/2)dx ≈ 0.785398
 */
#define EPANECHNIKOV_MASS   1.333333
#define TRIANGULAR_MASS     1.000000
#define TREXPONENTIAL_MASS  0.7357589
#define LAPLACE_MASS        1.0
#define NORMAL_MASS         1.0
#define BIWEIGHT_MASS       1.066667
#define TRICUBE_MASS        1.157143
#define COSINE_MASS         1.27324


#ifdef __cplusplus
extern "C" {
#endif
    // Function pointer type for kernel functions
    typedef void (*kernel_function)(const double*, int, double*);

    void C_kernel_eval(const int* ikernel,
                       const double* x,
                       const int* n,
                       double* y,
                       const double* scale);

    // Kernel function declarations
    void epanechnikov_kernel(const double *x, int n, double *w);
    void triangular_kernel(const double *x, int n, double *w);
    void tr_exponential_kernel(const double *x, int n, double *w);
    void laplace_kernel(const double *x, int n, double *w);
    void normal_kernel(const double *x, int n, double *w);
    void biweight_kernel(const double *x, int n, double *w);
    void tricube_kernel(const double *x, int n, double *w);
    void cosine_kernel(const double *x, int n, double *w);
    void hyperbolic_kernel(const double *x, int n, double *w);
    void const_kernel(const double* x, int n, double *w);

    void C_triangular_kernel_with_stop(const double *x, const int *rn, const double *rbw, int *stop, double *w);
    void C_epanechnikov_kernel_with_stop(const double *x, const int *rn, const double *rbw, int *stop, double *w);
    void C_tr_exponential_kernel_with_stop(const double *x, const int *rn, const double *rbw, int *stop, double *y);

    // External declaration of the kernel function pointer
    extern kernel_function kernel_fn;

    // Kernel initialization function
    void initialize_kernel(int ikernel, double scale);
#ifdef __cplusplus
}
#endif

// C++-only helper function
#ifdef __cplusplus
inline double get_kernel_mass(int kernel_type) {
    switch(kernel_type) {
        case TRIANGULAR:    return TRIANGULAR_MASS;
        case EPANECHNIKOV:  return EPANECHNIKOV_MASS;
        case TREXPONENTIAL: return TREXPONENTIAL_MASS;
        case LAPLACE:       return LAPLACE_MASS;
        case NORMAL:        return NORMAL_MASS;
        case BIWEIGHT:      return BIWEIGHT_MASS;
        case TRICUBE:       return TRICUBE_MASS;
        case COSINE:        return COSINE_MASS;
        default:           return 1.0; // Error case
    }
}
#endif

#endif // MSR2_KERNELS_H_

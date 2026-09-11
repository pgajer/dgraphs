# Quadform geodesic fixtures v1

Frozen scientific inputs; no solver results are implied.

| Case | Pairs | Purpose |
|---|---:|---|
| `flat2_ball` | 7 | Exact Euclidean control in a convex declared domain |
| `flat2_box` | 7 | Exact Euclidean control in a convex declared domain |
| `flat3_ball` | 7 | Exact Euclidean control in a convex declared domain |
| `flat3_box` | 7 | Exact Euclidean control in a convex declared domain |
| `flat4_ball` | 7 | Exact Euclidean control in a convex declared domain |
| `flat4_box` | 7 | Exact Euclidean control in a convex declared domain |
| `paraboloid2_disk` | 8 | Specialized smooth-solver baseline |
| `paraboloid2_square` | 8 | Same geometry and pairs on a larger domain |
| `saddle2_disk` | 8 | Shooting baseline and exact ruling |
| `saddle2_square` | 8 | Same saddle and pairs on the sampling square |
| `paraboloid2_rectangle` | 2 | Narrow rectangle; unrestricted candidates require containment checks |
| `saddle2_rectangle` | 2 | Narrow saddle patch, not its enclosing disk |
| `paraboloid2_high_curvature` | 8 | High curvature |
| `saddle2_high_curvature` | 8 | High curvature with ruling |
| `paraboloid2_radius64` | 8 | Large-radius continuation sentinel |
| `saddle2_radius64` | 7 | Large-radius shooting sentinel |
| `anisotropic2_disk` | 7 | Clairaut isotropic specialization is inapplicable |
| `cross_term2_square` | 7 | Non-diagonal indefinite symmetric form |
| `paraboloid3_ball` | 8 | 3D positive form with radial control |
| `mixed3_cube` | 8 | 3D mixed-index cube |
| `mixed4_ball` | 8 | 4D anisotropic mixed form |
| `mixed4_box` | 8 | 4D anisotropic mixed form |
| `multi_form2_square` | 7 | Codimension two; no single-height specialization |
| `paraboloid2_rigid_frame` | 8 | Ambient isometry and translation preserve distances |
| `paraboloid2_small_units` | 8 | Scale latent coordinates and divide forms by scale: F_new = scale * F |
| `paraboloid2_large_units` | 8 | Scale latent coordinates and divide forms by scale: F_new = scale * F |
| `regression_paraboloid4101` | 6 | Six actual former refinement outliers |
| `regression_paraboloid4102` | 1 | Former optimizer-degeneracy endpoints |
| `regression_saddle4101` | 2 | Cloud-level historical failure; offending pair was not retained |
| `regression_saddle4102` | 2 | Cloud-level historical failure; offending pair was not retained |

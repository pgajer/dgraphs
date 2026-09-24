# Stage 1 continuation after lossy R trace export

The paired 26-case numerical panel passed with exact native/Python coefficients, including 12 boundaries, six decision controls, eight full regressions, four 500-profile geometries and the 1,000-profile helix. The strict native and R controls then completed all four small examples, and all four R result objects exactly match the preserved typed baseline under the declared timing/build exclusions.

The strict PreSSMat native/R trace comparison failed because jsonlite rounded a trace multiplier from 0.6625000000000001 to 0.6625 on export. The saved RDS object remains the primary R result. Earlier strict trace comparisons tolerated other tiny export rounding differences; those comparisons are replaced by a precision-preserving export and a read-only recheck of all four saved objects. Preserve the original JSON and failed comparison. No baseline engine calls are repeated.

Use an explicit 17-significant-digit numeric JSON projection for subsequent R test traces; this is a test serializer only, not an engine or R adapter change. Resume the remaining R candidate and restart/failure controls, counting the eight completed strict calls and 32 attempts in cumulative limits. All earlier calls remain counted. Acceptance limits and numerical policy are unchanged.

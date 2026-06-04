#ifndef CIRCULAR_PARAM_RESULT_H_
#define CIRCULAR_PARAM_RESULT_H_

struct circular_param_result_t {
	std::vector<double> angles;      // Angles for each vertex
	std::vector<double> eig_vec2;    // Second eigenvector
	std::vector<double> eig_vec3;    // Third eigenvector
	std::vector<double> eig_vec4;    // 4-th eigenvector
	std::vector<double> eig_vec5;    // 5-th eigenvector
	std::vector<double> eig_vec6;    // 6-th eigenvector
};

#endif // CIRCULAR_PARAM_RESULT_H_

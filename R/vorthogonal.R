vorthogonal <- function(N){

	# http://math.stackexchange.com/questions/137362/how-to-find-perpendicular-vector-to-another-vector
	# FINDS RANDOM VECTOR PERPENDICULAR TO GIVEN VECTOR N

	N <- uvector(N)

	if(N[1] == -sqrt(2)/2 && N[2] == sqrt(2)/2 && N[3] == 0){
		T <- c(-N[2] - N[3], N[1], N[1])
	}else if(N[1] == sqrt(2)/2 && N[2] == -sqrt(2)/2 && N[3] == 0){
		T <- c(-N[2] - N[3], N[1], 0)
	}else{
		T <- c(N[3], N[3], -N[1] - N[2])
	}

	T
}
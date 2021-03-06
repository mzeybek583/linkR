defineLinkage <- function(joint.coor, joint.types, joint.cons, 
	joint.conn = NULL, link.points = NULL, link.assoc = NULL, 
	link.names = NULL, ground.link = NULL, path.connect = NULL, 
	lar.cons = NULL){

	# MAKE SURE JOINT COORDINATES ARE MATRIX
	if(is.vector(joint.coor)) joint.coor <- matrix(joint.coor, nrow=1)

	# VALIDATE INPUTS
	if(!is.null(link.points) && is.null(link.assoc)) stop("'link.assoc' is NULL. If 'link.points' is defined, 'link.assoc' must be non-NULL.")
	if(!is.null(joint.conn) && nrow(joint.conn) != length(joint.types)) stop(paste0("The number of rows in 'joint.conn' (", nrow(joint.conn), ") must be equal to the number of joints specified in 'joint.types' (", length(joint.types), ")."))
	if(length(joint.types) != nrow(joint.coor)) stop(paste0("The number of rows in 'joint.coor' (", nrow(joint.coor), ") must be equal to the number of joints specified in 'joint.types' (", length(joint.types), ")."))

	# MAKE SURE JOINT TYPE LETTERS ARE UPPERCASE FOR STRING MATCHING
	if(!is.null(joint.types)) joint.types <- toupper(joint.types)

	# DEFAULT NULLS
	point.assoc <- NULL
	
	# IF JOINT MATRIX IS 2D, ADD THIRD DIMENSION AS ZERO
	if(ncol(joint.coor) == 2) joint.coor <- cbind(joint.coor, rep(0, nrow(joint.coor)))

	# IF JOINT CONSTRAINTS ARE 2D, ADD THIRD DIMENSION AS ZERO
	if(!is.null(joint.cons)){
		if(is.matrix(joint.cons) && ncol(joint.cons) == 2) joint.cons <- cbind(joint.cons, rep(0, nrow(joint.cons)))
		if(is.list(joint.cons)){
			for(i in 1:length(joint.cons)) if(!is.na(joint.cons[[i]][1]) && length(joint.cons[[i]]) == 2) joint.cons[[i]] <- c(joint.cons[[i]], 0)
		}
	}

	# IF JOINT CONSTRAINT VECTORS ARE NULL, DEFINE R-JOINTS AS FOR PLANAR 4-BAR

	# MAKE SURE THAT LINKAGE TYPE IS ALLOWED

	# IF JOINT CONSTRAINTS ARE MATRIX, CONVERT TO LIST
	if(is.matrix(joint.cons)){
		joints_cvec <- list()
		for(i in 1:nrow(joint.cons)) if(!is.na(joint.cons[i, 1])) joints_cvec[[i]] <- joint.cons[i, ]
		joint.cons <- joints_cvec
	}

	# ADD ROWNAMES TO JOINTS (NAME BASED ON JOINT TYPE AND ORDER IN INPUT SEQUENCE)
	if(is.null(rownames(joint.coor))){
		joint_names <- rep(NA, nrow(joint.coor))
		for(i in 1:nrow(joint.coor)){
			if(i == 1){
				joint_names[i] <- paste0(joint.types[i], i)
			}else{
				joint_names[i] <- paste0(joint.types[i], 1 + sum(joint.types[1:(i-1)] == joint.types[i]))
			}
		}
		rownames(joint.coor) <- joint_names
	}

	# ADD ROWNAMES TO CONSTRAINT LIST
	if(is.null(names(joint.cons))) names(joint.cons) <- rownames(joint.coor)
	
	# MAKE CONSTRAINTS VECTORS UNIT VECTORS
	for(i in 1:length(joint.cons)) if(!is.na(joint.cons[[i]]) && is.vector(joint.cons[[i]])) joint.cons[[i]] <- uvector(joint.cons[[i]])

	# AUTOMATICALLY DEFINE PAIRS AS SIMPLE CHAIN IF NOT SPECIFIED
	if(is.null(joint.conn)){
		joint.conn <- matrix(NA, nrow=nrow(joint.coor), ncol=2)
		for(i in 1:nrow(joint.coor)){
			if(i < nrow(joint.coor)){
				joint.conn[i, ] <- c(i-1, i)
			}else{
				joint.conn[i, ] <- c(i-1, 0)
			}
		}
	}

	# ASSIGN DEGREES OF FREEDOM
	dof_joints <- setNames(c(1,1,2,3), c("R", "L", "P", "S"))

	# CHECK FOR LINK NAMED 'GROUND'
	if(is.null(ground.link) && !is.numeric(joint.conn[1,1])){
		all_link_names <- unique(c(joint.conn))
		ground_grepl <- grepl('^ground$', all_link_names, ignore.case=TRUE)
		if(sum(ground_grepl) > 0){
			ground.link <- all_link_names[ground_grepl]
			link.names <- c(ground.link, all_link_names[all_link_names != ground.link])
		}else{
			stop('Please indicate one of the links in "joint.conn" as "Ground".')
		}
	}

	# SET LINK NAMES IF GROUND IS DEFINED
	if(is.null(link.names) && !is.null(ground.link)){
		link.names <- ground.link
		all_link_names <- unique(c(joint.conn))
		link.names <- c(link.names, all_link_names[all_link_names != ground.link])
	}

	# SET JOINT PAIRS AS NUMERIC INDICES TO LINKS
	if(!is.null(link.names) && !is.numeric(joint.conn[1,1])){
		for(i in 1:nrow(joint.conn)) joint.conn[i, ] <- c(which(joint.conn[i, 1] == link.names), which(joint.conn[i, 2] == link.names))
		joint.conn <- matrix(as.numeric(joint.conn), nrow=nrow(joint.conn), ncol=ncol(joint.conn)) - 1
	}

	# GET UNIQUE INDICES OF LINKS
	link_idx_unique <- unique(c(joint.conn))

	# GET NUMBER OF LINKS
	num_links <- length(link_idx_unique)

	# IF LINK.NAMES IS NULL, SET TO DEFAULT
	if(is.null(link.names)) link.names <- c("Ground", paste0("Link", 1:(num_links-1)))

	# LONG-AXIS ROTATION CONSTRAINTS
	lar_cons <- NULL
	if(!is.null(lar.cons)){
		
		lar_cons <- sapply(link.names, function(x) NULL)

		for(i in 1:length(lar.cons)){
		
			if(is.numeric(lar.cons[[i]]$link)){
				idx <- link.names[lar.cons[[i]]$link]
			}else{
				idx <- lar.cons[[i]]$link
			}
			
			lar_cons[[idx]] <- lar.cons[[i]]

			# MAKE UNIT VECTOR
			lar_cons[[idx]]$vec <- uvector(lar_cons[[idx]]$vec)
			
			# SAVE INITIAL POINT
			lar_cons[[idx]]$point.i <- lar_cons[[idx]]$point
		}
	}

	# FIND LINKAGE DEGREES OF FREEDOM
	# BUG:
	#	NOT RETURNING THE CORRECT NUMBER FOR OWL CRANIAL LINKAGE NETWORK...
	# 	RETURNS 6 BUT SHOULD BE 7 (1 + 6 LONG-AXIS ROTATIONS)
	# 	RETURNS CORRECT NUMBER FOR SALMON HYOID-LOWER JAW LINKAGE (2 + 5 LONG-AXIS ROTATIONS)
	dof <- 6*(length(unique(c(joint.conn))) - 1) - 6*length(joint.types) + sum(dof_joints[unlist(joint.types)])

	# CREATE MATRIX FOR CONSTRAINED LENGTHS BETWEEN JOINTS
	joint.links <- matrix(NA, nrow=0, ncol=4, dimnames=list(NULL, c('Link.idx', 'Joint1', 'Joint2', 'Length')))
	if(nrow(joint.coor) > 1){

		for(link_idx in link_idx_unique){

			# FIND ALL JOINTS CONNECTED TO LINK
			joints_comm <- (1:nrow(joint.conn))[(rowSums(link_idx == joint.conn) == 1)]
		
			# JOINTS CONNECTED TO GROUND
			if(link_idx == 0){
				for(i in 1:length(joints_comm)) joint.links <- rbind(joint.links, c(link_idx, 0, joints_comm[i], 0))
				next
			}

			# GENERATE UNIQUE PAIRS AND CALCULATE DISTANCE BETWEEN JOINTS IN PAIR
			for(i in 1:(length(joints_comm)-1)){
				for(j in (i+1):(length(joints_comm))){
					joint.links <- rbind(joint.links, c(link_idx, joints_comm[i], joints_comm[j], sqrt(sum((joint.coor[joints_comm[i], ]-joint.coor[joints_comm[j], ])^2))))
				}
			}
		}

		# IDENTIFY GROUND JOINTS - REMOVE ZERO
		ground_joints <- joint.links[joint.links[, 1] == 0, 'Joint2']

		# CREATE CONNECTED JOINT SEQUENCES
		joint_paths <- connJointSeq(joint.links, joint.types, joint.conn, ground_joints)

	}else{
		joint.links <- rbind(joint.links, c(0,0,1,0))
		ground_joints <- 0:1
		joint_paths <- NULL
	}

	# CREATE LOCAL COORDINATE SYSTEMS
	link.lcs <- setNames(vector("list", length(link.names)), link.names)

	for(link_idx in link_idx_unique){

		#print(names(link.lcs)[link_idx+1])

		# FIND ALL JOINTS CONNECTED TO LINK
		joints_comm <- unique(c(joint.links[joint.links[, 'Link.idx'] == link_idx, c('Joint1', 'Joint2')]))

		# REMOVE ZERO JOINT
		joints_comm <- joints_comm[joints_comm > 0]

		# REMOVE NA VALUES
		joints_comm <- joints_comm[!is.na(joints_comm)]
		
		if(length(joints_comm) > 0){

			is_ground <- rep(FALSE, length(joints_comm))
			for(i in 1:length(joints_comm)) is_ground[i] <- joints_comm[i] %in% ground_joints

			# IF THERE IS ONE GROUND JOINT MAKE THAT THE ORIGIN
			if(sum(is_ground) == 1){
				lcs_origin <- joint.coor[joints_comm[is_ground], ]
			}else{
				lcs_origin <- colMeans(joint.coor[joints_comm, ])
			}
		}else{

			# GET LINK NAME
			lcs_link_name <- link.names[link_idx+1]

			# 
			if(is.null(link.points) || (!is.null(link.points) && !lcs_link_name %in% link.assoc)){

				# IF NO POINTS ASSOCIATED WITH LINK, CENTER LCS AROUND SOLE JOINT
				lcs_origin <- joint.coor[1, ]

			}else{

				# GET POINTS ASSOCIATED WITH LCS LINK
				lcs_pts <- matrix(link.points[link.assoc == lcs_link_name, ], nrow=sum(link.assoc == lcs_link_name), ncol=3)

				# SET ORIGIN
				lcs_origin <- colMeans(lcs_pts, na.rm=TRUE)
			}
		}

		link.lcs[[names(link.lcs)[link_idx+1]]] <- matrix(c(lcs_origin, lcs_origin+c(1,0,0), 
			lcs_origin+c(0,1,0), lcs_origin+c(0,0,1)), nrow=4, ncol=3, byrow=TRUE)
	}
	
	if(!is.null(link.points)){
		
		# IF link.points ARE VECTOR CONVERT TO MATRIX
		if(is.vector(link.points)) link.points <- matrix(link.points, ncol=length(link.points))

		# IF POINT MATRIX IS 2D, ADD THIRD DIMENSION AS ZERO
		if(ncol(link.points) == 2) link.points <- cbind(link.points, rep(0, nrow(link.points)))
		
		# MAKE SURE LINK.ASSOC IS OF THE SAME LENGTH AS link.points
		if(length(link.assoc) != nrow(link.points)) stop(paste0("The length of 'link.assoc' (", length(link.assoc), ") must be the same as the number of rows in 'link.points' (", nrow(link.points), ")."))

		# SET THE link.points ASSOCIATED WITH EACH LINK
		point.assoc <- setNames(vector("list", length(link.names)), link.names)
		
		# IF LINK.ASSOC ARE NUMERIC INTEGERS
		if(is.numeric(link.assoc[1])){
			for(i in 1:length(link.assoc))
				point.assoc[[names(point.assoc)[link.assoc[i]+1]]] <- c(point.assoc[[names(point.assoc)[link.assoc[i]+1]]], i)
		}else{
			for(i in 1:length(link.assoc)) point.assoc[[link.assoc[i]]] <- c(point.assoc[[link.assoc[i]]], i)
		}
	}

	linkage <- list(
		'joint.coor' = joint.coor,
		'joint.cons' = joint.cons,
		'joint.types' = joint.types,
		'joint.links' = joint.links,
		'joint.paths' = joint_paths,
		'joint.conn' = joint.conn,
		'joint.init' = joint.coor,
		'ground.joints' = ground_joints,
		'link.points' = link.points,
		'point.assoc' = point.assoc,
		'link.assoc' = link.assoc,
		'link.names' = link.names,
		'path.connect' = path.connect,
		'link.lcs' = link.lcs,
		'lar.cons' = lar_cons,
		'num.links' = num_links,
		'dof' = dof
	)

	class(linkage) <- 'linkage'

	linkage
}

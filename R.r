# **********************************************************************************************************************
# ** Pennekamp & Schtickzelle (2013)                                                                                  **
# ** Implementing image analysis in laboratory-based experimental systems for ecology and evolution: a hands-on guide **
# ** R and EBImage script for digital image analysis                                                                  **   
# **********************************************************************************************************************

#load EBImage package to perform image analysis
library("EBImage")

# **************************************************************************** 
# **                    Start of USER SECTION                                 **
# ****************************************************************************

#specify input directory
dir_input = "C:\\MEE\\Images\\1 - Photos to analyze\\"

#specify directory with photos for comparison
dir_compare = "C:\\MEE\\Images\\2 - Photos for comparison\\"

#specify output directory
dir_output = "C:\\MEE\\Results\\R\\"

#specify segmentation approach (i.e. 'threshold', 'difference image' or 'edge detection')
seg = 'threshold'

#specify whether you want to split objects by watershed after segmentation (if yes, put 'ws', else '_')
split = '_ws_'

#specify size boundaries
min_size = 200
max_size = 1500

# **************************************************************************** 
# **                    End of USER SECTION                                   **
# ****************************************************************************

# 1. LOOPING OVER THE IMAGE DIRECTORY AND READING OF IMAGE DATA
#--------------------------------------------------------------
# initialize counter
i = 1

# loop over the input directory
while (i <= length(list.files(dir_input))){
  
  # check that one segmentation approach is selected, otherwise stop the program
  if (seg == 'threshold' | seg == 'difference image' | seg == 'edge detection') {
    
  # read reference image to be analyzed (the image origin (0,0) is the lower left corner)
    image <- readImage(paste(dir_input,i,".jpg",sep=""))
  # convert image to grayscale
    image <- channel(image,'gray')
  # flip image to have same position of the image origin at the lower left corner facilitating comparison with ImageJ and Python
    image <- flip(image)

# 2a. SEGMENTING IMAGE DATA BY THRESHOLDING, DIFFERENCE IMAGE OR EDGE DETECTION
#-----------------------------------------------------------------------------

    if (seg == 'threshold'){
      # select global threshold to segment image (NB: intensity values (0-255) are normalized between 0 and 1)
      image_segmented <- image > 0.546875
  }
    
    if (seg == 'difference image'){
      # produce difference image to detect moving particles
      # load sequential image that is used for the comparison
      image2 <- readImage(paste(dir_compare,i,".jpg",sep=""))
      image2 <- channel(image2,'gray')
      image2 <- flip(image2)
      # subtract first from second image, to get difference in intensity values
      difference_image <- image - image2
      # threshold difference image to get mask for labelling (images normalized after conversion to float, therefore intensity between 0 and 1)
      image_segmented <- difference_image > 0.25
	}
    
    if (seg == 'edge detection'){
      # perform edge detection.
      f = array(1, dim=c(3, 3))
      f[2, 2] = -4
      edges = filter2(image, f)
      # threshold edges to select only strong contours (intensities are always normalized)
      image_segmented <- edges > 0.99
      }

      # fill potential holes in segmented objects
      image_segmented_filled <- fillHull(image_segmented)
    
      # watershed segmentation to split touching objects, if activated in the user's section	
      if (split == '_ws_'){
      # distance map is created where the distance of each foreground pixel to the closest background pixel is calculated and used for watershed splitting
      map <- distmap(image_segmented_filled)/10
      # return labelled image (array of unique integers per object)
      image_label <- watershed(map, tolerance=0.15, ext=1)
	}

# 2b. WATERSHED SPLIT
#--------------------	

    if (split != '_ws_'){
      # return labelled image (array of unique integers per object)
      image_label <- bwlabel(image_segmented_filled)
	}
	
# 3. MEASURE OBJECT PROPERTIES AND CONDUCT SIZE-BASED EXCLUSION
#--------------------------------------------------------------
		
    # measure object size on labelled image
    size <- computeFeatures.shape(image_label, properties=FALSE)
    intensity <- computeFeatures.basic(image_label, image, properties=FALSE)
    spatial <- computeFeatures.moment(image_label, properties=FALSE)
    intensity[,1] <- intensity[,1]*256
    intense <- intensity[,0:1]
    space <- spatial[,1:3]
    morph <- size[,1:2]
    results <- cbind(intense,space,morph)
    results_df <- as.data.frame(results)
        
    # exclude objects outside of size boundaries
    # re-label image after exclusion of too small and too big objects
    image_label_clean <- rmObjects(image_label,which(results[,5] < min_size | results[,5] > max_size, ))
    
    # check whether there are objects that meet the size range, otherwise skip output production
    if (!max(image_label_clean)==0){
    results_clean <- subset(results_df, results[,5] > min_size & results[,5] < max_size, select=1:6)
    results_clean$label <- seq(1:length(results_clean[,1]))
    results_clean <- results_clean[c("label","intense", "m.cx","m.cy","s.area","s.perimeter","m.majoraxis")]
        
# 4. EXPORT RESULTS AS OVERLAY OF IDENTIFIED OBJECTS AND TABLE OF OBJECT MEASUREMENTS
#-----------------------------------------------------------------------------------
	
    # plot overlay between original picture and identified objects
    image_RGB <- channel(image, 'rgb')
    # find outline of objects for plotting
    overlayObjects <- paintObjects(image_label_clean, image_RGB, col=c('red'))
    # reverse initial flip of image before plotting
    overlayObjects <- flip(overlayObjects)    

    # export results and create overlay for error checking
    width <- length(image[,1])
    height <- length(image[1,])
    write.table(results_clean, paste(dir_output,seg,split,i,"_results.txt",sep=""), sep="\t",row.names = FALSE, col.names=TRUE)
    jpeg(filename = paste(dir_output,"overlay_",seg,split,i,".jpg",sep=""), width = width, height = height, pointsize = 12, quality = 400)
    par(mar=c(0,0,0,0))
    plot(x = NULL, y = NULL, xlim = c(0,as.numeric(width)), ylim = c(0,as.numeric(height)), pch = '', xaxt = 'n', yaxt = 'n', xlab = '', ylab = '', xaxs = 'i', yaxs = 'i', bty = 'n') # plot empty figure
    rasterImage(overlayObjects, xleft = 0, ybottom = 0, xright = width, ytop = height) 
    text(results_clean$m.cx,results_clean$m.cy,labels=results_clean$label, col='red')
    dev.off()
    # increase counter
    i <- i+1 }
    else {
    # increase counter
    i <- i+1 }
  }
  
  else{
    stop("Select one of four segmentation approaches")
  }

}







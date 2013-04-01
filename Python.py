# **********************************************************************************************************************
# ** Pennekamp & Schtickzelle (2013)                                                                                  **
# ** Implementing image analysis in laboratory-based experimental systems for ecology and evolution: a hands-on guide **
# ** Python and scikits image script for digital image analysis                                                       **   
# **********************************************************************************************************************

# packages needed to perform image processing and analysis
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import scipy.ndimage as nd
from skimage.util import img_as_float, img_as_ubyte
from skimage.io import imread
from skimage.morphology import watershed, is_local_maximum
from skimage.filter import sobel
from skimage.measure import regionprops
from skimage.segmentation import find_boundaries, visualize_boundaries
from skimage.color import gray2rgb, rgb2gray
from skimage.morphology import label
from matplotlib.backends.backend_agg import FigureCanvasAgg as FigureCanvas
import csv
import os

# **************************************************************************** 
# **                    Start of USER SECTION                                 **
# ****************************************************************************

# specify input directory
dir_input = 'c:\\MEE\\Images\\1 - Photos to analyze\\'

# specify directory with photos for comparison
dir_compare = 'c:\\MEE\\Images\\2 - Photos for comparison\\'

# specify output directory
dir_output = 'c:\\MEE\\Results\\Python\\'

# specify segmentation approach (i.e. 'threshold', 'difference image' or 'edge detection')
seg = 'threshold'

# specify whether you want to split objects by watershed after segmentation (if yes, put '_ws_', else '_')
ws = '_ws_'

#specify size boundaries to exclude objects that are smaller/bigger than the min_size/max_size
min_size = 200
max_size = 1500

# **************************************************************************** 
# **                    End of USER SECTION                                   **
# ****************************************************************************

# deactivate interactive mode of matplotlib
ioff()

# 1. LOOPING OVER THE IMAGE DIRECTORY AND READING OF IMAGE DATA
#--------------------------------------------------------------

# initialize counter
i = 1

# loop over the input directory
while i <= len(os.listdir(dir_input)):

    # check that one segmentation approach is selected, otherwise stop the program
    if seg not in ('threshold','difference image','edge detection'):
        print "Select one of three segmenting techniques"
        break

    # read reference image to be analyzed (the image origin (0,0) is the upper left corner)
    image = mpimg.imread(dir_input+str(i)+'.jpg')
    image = img_as_ubyte(rgb2gray(image))

# 2a. SEGMENTING IMAGE DATA BY THRESHOLDING, DIFFERENCE IMAGE OR EDGE DETECTION
#-----------------------------------------------------------------------------

    if seg == 'threshold':
        # select global threshold to segment image (between 0 and 255)
        image_segmented = image > 140
  	
    if seg == 'difference image':
        # produce difference image to detect moving particles
		# load sequential image that is used for the comparison
        image2 = mpimg.imread(dir_compare+str(i)+'.jpg')
        image2 = img_as_ubyte(rgb2gray(image2))
        # first convert both arrays to float prior to subtraction, so that values are not shifted into the positive domain when negative due to subtraction
        img_float = img_as_float(image)
        img2_float = img_as_float(image2)
        # subtract first from second image, to get difference in intensity values
        img_diff = img_float - img2_float
        # threshold difference image to get mask for labelling (image intensity normalized after conversion to float, therefore intensity between 0 and 1)
        image_segmented = img_diff > 0.25	
		
    if seg == 'edge detection':
	    # perform edge detection. Different edge filters are available in Python, here the Sobel filter is used
        edges = sobel(image)
        # threshold edges to select only strong contours (NB: intensity values (0-255) are normalized between 0 and 1)
        image_segmented = edges > 0.1
 
	# fill potential holes in segmented objects
    image_segmented_filled = nd.binary_fill_holes(image_segmented)
	
    #watershed segmentation to split touching objects, if activated in the user's section	
    if ws == '_ws_':
        # distance map is created where the distance of each foreground pixel to the closest background pixel is calculated and used for watershed splitting
        distance = nd.distance_transform_edt(image_segmented_filled)
		# apply Gaussian filter to the distance map to merge several local maxima into one
        distance=nd.gaussian_filter(distance,4)
        local_maxi = is_local_maximum(distance, labels=image_segmented_filled, footprint=np.ones((3, 3)))
        markers = nd.label(local_maxi)[0]
		# return labelled image (array of unique integers per object)
        labelled_image = watershed(-distance, markers, mask=image_segmented_filled)

# 2b. WATERSHED SPLIT
#--------------------

    # return labelled image (array of unique integers per object)
    if ws != '_ws_':
        labelled_image, nb_labels = nd.label(image_segmented_filled)

# 3. MEASURE OBJECT PROPERTIES AND CONDUCT SIZE-BASED EXCLUSION
#--------------------------------------------------------------
		
    # measure object size on labelled image
    props = regionprops(labelled_image, properties=['Area'], intensity_image=image)

    # exclude objects outside of size boundaries
    size_exclude = [0]
    for j in props:
		# first element zero to account for background labelled as 0
        size_exclude.append(j['Area'])
  
    size_exclude_array = array(size_exclude)
    size_exclude_mask = (size_exclude_array < min_size) | (size_exclude_array > max_size)
    remove_pixel = size_exclude_mask[labelled_image]
    labelled_image[remove_pixel] = 0

	# re-label image after exclusion of too small and too big objects
    labels = np.unique(labelled_image)
    labelled_image = np.searchsorted(labels, labelled_image)
	
	# measure object properties after cleaning
    props_final = regionprops(labelled_image, properties=['MeanIntensity', 'Centroid', 'Area', 'Perimeter','MajorAxisLength'], intensity_image=image)

# 4. EXPORT RESULTS AS OVERLAY OF IDENTIFIED OBJECTS AND TABLE OF OBJECT MEASUREMENTS
#-----------------------------------------------------------------------------------
	
	# export results 
	# transform Python dictionary into csv file to store object properties
	# centroid tuple in X and Y coordinate for easy transformation into csv file
    coords = []
    object_label = []
    for k in props_final:
        object_label.append(k["Label"])
        coords.append(k["Centroid"])
        Y, X = list(k["Centroid"])
        k["X"] = X
        k["Y"] = Y
        del k['Centroid']
	
    fieldnames = ['Label', 'MeanIntensity', 'Y', 'X', 'Area', 'Perimeter','MajorAxisLength']
    output_results = dir_output+seg+ws+str(i)+'_results.txt'
    test_file = open(output_results,'wb')
    csvwriter = csv.DictWriter(test_file, delimiter='\t', fieldnames=fieldnames)
    csvwriter.writerow(dict((fn,fn) for fn in fieldnames))
    for row in props_final:
        csvwriter.writerow(row)
    test_file.close()
	
    # find outline of objects for plotting
    boundaries = find_boundaries(labelled_image)
    img_rgb = gray2rgb(image)
    overlay = np.flipud(visualize_boundaries(img_rgb,boundaries))
	
	# plot overlay between original picture and identified objects
	# coordinates are delivered as tuples with first height and then width, opposite to plotting first x (width) and then y (height)
    coords_rev = [(b, a) for a, b in coords]
    rcParams['savefig.dpi'] = 700
    fig = figure(figsize=(9.36, 6.24))
    canvas = FigureCanvas(fig)
    plot = fig.add_subplot(111)
    for label, xy in zip(object_label, coords_rev):
        plot.annotate(label,xy=xy,xytext=None,ha='center',va='center',color='red',fontsize=1)
    plot.imshow(np.flipud(overlay))
    height, width = image.shape
    plot.set_xlim(0, width)
    plot.set_ylim(0, height)
    plot.get_xaxis().set_visible(False)
    plot.get_yaxis().set_visible(False)
    plt.savefig(dir_output+'overlay_'+seg+ws+str(i)+'.jpg', bbox_inches='tight', pad_inches=0.01, dpi=(700))
    plt.close()

# increase counter
    i += 1

# re-activate interactive mode of matplotlib
ion()

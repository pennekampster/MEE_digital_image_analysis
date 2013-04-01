// **********************************************************************************************************************
// ** Pennekamp & Schtickzelle (2013)                                                                                  **
// ** Implementing image analysis in laboratory-based experimental systems for ecology and evolution: a hands-on guide **
// ** ImageJ script for digital image analysis                                                                         **   
// **********************************************************************************************************************

// **************************************************************************** 
// **                    Start of USER SECTION                               **
// ****************************************************************************

// specify input directory
dir_input = 'c:\\MEE\\Images\\1 - Photos to analyze\\'

// specify directory with photos for comparison
dir_compare = 'c:\\MEE\\Images\\2 - Photos for comparison\\'

// specify output directory
dir_output = 'c:\\MEE\\Results\\ImageJ\\'

// specify segmentation approach (i.e. 'threshold', 'difference image' or 'edge detection')
seg = 'threshold'

// specify whether you want to split objects by watershed after segmentation (if yes, put 'ws', else '_')
ws = '_ws_'; 

// specify size boundaries to exclude objects that are smaller/bigger than the min_size/max_size
min_size = 200
max_size = 1500

// **************************************************************************** 
// **                    End of USER SECTION                                 **
// ****************************************************************************

// work in batch mode to prevent display of images and run faster
setBatchMode(true);

// 1. LOOPING OVER THE IMAGE DIRECTORY AND READING OF IMAGE DATA
//--------------------------------------------------------------

list = getFileList(dir_input);

// loop over the input directory
for (i=0; i<list.length; i++) {

// check that one segmentation approach is selected
if (seg == 'threshold' || seg == 'watershed' || seg == 'edge detection' || seg == 'difference image'){
    
// read reference image to be analyzed (the image origin (0,0) is the upper left corner)
open(dir_input+list[i]);
  
// create duplicate image for later measurements on pixel intensities
run("Duplicate...", "title"); 

// 2a. SEGMENTING IMAGE DATA BY THRESHOLDING, DIFFERENCE IMAGE OR EDGE DETECTION
//------------------------------------------------------------------------------

  if (seg=='threshold') {
    // select global threshold to segment image
    selectWindow(list[i]);
    setThreshold(0, 140, "black & white");
    run("Convert to Mask");
    run("Invert");}

  if (seg=='difference image') {
    // produce difference image to detect moving particles
    // load sequential image that is used for the comparison
    open(dir_compare+list[i]);
    rename('compare_'+list[i]);
    
    // subtract first from second image, to get difference in intensity values
    imageCalculator("Subtract create", list[i], 'compare_'+list[i]);
    selectWindow(list[i]);
    close();
    selectWindow('compare_'+list[i]);
    close();
    selectWindow("Result of "+list[i]);
    rename(list[i]);
    selectWindow(list[i]);
    
    // threshold difference image to get mask for labelling
    setThreshold(0, 64, "black & white");
    run("Convert to Mask");
    run("Invert");}
	
  if (seg=='edge detection') {
    // perform edge detection.
    selectWindow(list[i]);
    run("Find Edges");
    
    // threshold edges to select only strong contours 
    setAutoThreshold("Default dark");
    setThreshold(200, 255);
    run("Convert to Mask");}

// fill potential holes in segmented objects
run("Fill Holes");

// watershed segmentation to split touching objects, if activated in the user's section	
if (ws=='_ws_') {

// 2b. WATERSHED SPLIT
//--------------------

  // use watershed algorithm to divide overlapping cells
  run("Watershed");}

// 3. MEASURE OBJECT PROPERTIES AND CONDUCT SIZE-BASED EXCLUSION
//--------------------------------------------------------------

// measure object size on labelled image (exclude objects outside of size boundaries)
run("Set Measurements...", "mean center area perimeter fit invert redirect="+replace(list[i],".JPG","-1.JPG")+" decimal=3");
selectWindow(list[i]);
run("Analyze Particles...", "size="+min_size+"-"+max_size+" circularity=0.00-1.00 show=Outlines include");
selectWindow(list[i]);
close();

// plot overlay between original picture and identified objects
open(dir_input+list[i]);
run("RGB Color"); 
selectWindow("Drawing of "+list[i]);
run("RGB Color");
setMinAndMax(-126, 128, 4);
run("Apply LUT");

imageCalculator("AND create", "Drawing of "+list[i], list[i]);
selectWindow(list[i]);
close();
selectWindow("Drawing of "+list[i]);
close();

// 4. EXPORT RESULTS AS OVERLAY OF IDENTIFIED OBJECTS AND TABLE OF OBJECT MEASUREMENTS
//-----------------------------------------------------------------------------------

// export results 
saveAs("measurements", dir_output+seg+ws+replace(list[i],".JPG","")+"_results.txt");
selectWindow("Result of Drawing of "+list[i]);
saveAs("jpg", dir_output+"overlay_"+seg+ws+replace(list[i],".JPG",""));
close();

run("Clear Results");
close();

}    

// check that one segmentation approach is selected, otherwise stop the program
else {print('Choose one of three segmentation approaches!');}

}
     

 

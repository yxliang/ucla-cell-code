%%% Bino Abel Varghese
%%% Code to track cells
%%% First part of the code

function [transitTimeData] = CellTracking(numFrames, framerate, template, processedFrames, xOffset, cellVideo)

close all;
progressbar([],[],0)
% Change WRITEVIDEO_FLAG to true in order to print a video of the output,
% defaults to false.
WRITEVIDEO_FLAG = false;

%% Initializations
firstFrame = true;
counter = 0;
line = 0;
write = true;

% HARD CODED x coordinates for the center of each lane (1-16), shifted by
% the offset found in 'MakeWaypoints'
laneCoords = [16 48 81 113 146 178 210 243 276 308 341 373 406 438 471 503] + xOffset;

% The cell structure 'cellInfo' is an important structure that stores 
% information about each cell.  It contains 16 arrays, one for each lane in
% the device.  Each array is initialized to a default length 
% of 1,500 rows, and the code checks that the array is not full at the end 
% of each loop.  If the array is full, it is enlarged. The columns are:
%   1) Frame number
%   2) cell label number
%   3) Grid line that the cell intersects
%   4) Cell area (in pixels)
cellInfo = cell(1,16);
for ii = 1:16
   cellInfo{ii} = zeros(300,4);
end

% In order to remember which index to write to in each of the arrays in
% cellInfo, a counter variable is needed.  laneIndex gives the index for
% each lane.
laneIndex = ones(1,16);

% The array checkingArray is 'number of horizontal lines' x 'number of
% lanes'.  Each time a cell is found, the position (lane and line) is
% known.  These are used as indicies (for instance, a cell at line 2 in
% lane 4 will check checkingArray(2,4)).  At each position, the last frame
% at which a cell was previously found in that position is stored.  The
% cell is only stored as a cell if no cell was found in sequential previous
% frames.  If the frame stored at that position is 0 or 2 less than the
% current frame, the cell is counted (write is turned true)
checkingArray = zeros(7,16);

%% Labels each grid line in the template from 1-7 starting at the top
[tempmask, ~] = bwlabel(template);

% Preallocates an array to store the y coordinate of each line
lineCoordinate = zeros(1,7);

% Uses the labeled template to find the y coordinate of each line
for jj = 1:7
    q = regionprops(ismember(tempmask, jj), 'PixelList');
    lineCoordinate(jj) = q(1,1).PixelList(1,2);
end
clear tempmask;

%% Opens a videowriter object if needed
if(WRITEVIDEO_FLAG)
   outputVideo = VideoWriter('C:\Users\Mike\Desktop\output_video.avi','Uncompressed AVI');
   outputVideo.FrameRate = cellVideo.FrameRate;
   open(outputVideo) 
end

%% Cell Labeling
% This loop goes through the video frame by frame and labels all of the
% cells.  It stores (in cellInfo), the centroids and line intersection of
% each cell.
for ii = 1:numFrames
    % currentFrame stores the frame that is currently being processed
    currentFrame = processedFrames(:,:,ii);
    % Allocates a working frame (all black).  Any cell in the current
    % frame that is valid (touching a line and of a certain size) will be
    % added into working frame.
    workingFrame = false(size(currentFrame));
    
    % If the current frame has any objects in it.  Skips any empty frames.
    if any(currentFrame(:) ~= 0)
        %% Label the current frame
        % Count number of cells in the frame and label them
        % (numLabels gives the number of cells found in that frame)
        [labeledFrame, numLabels] = bwlabel(currentFrame);
        % Compute their centroids
        cellCentroids = regionprops(labeledFrame, 'centroid', 'area');
        
        %% Check which line the object intersects with
        % If firstFrame is true (meaning this is the first frame), looks
        % for the first frame with an object intersecting the top line.
        for jj = 1:numLabels
            currentRegion = ismember(labeledFrame, jj);
            
            % For the first frame
            if firstFrame
                % If the cell intersects line 1, add it to workingFrame,
                % and set firstFrame = false.
                if(sum(currentRegion(lineCoordinate(1),:)) ~= 0)
                    % workingFrame = workingFrame | currentRegion;
                    counter = counter + 1;
                    % Indicates that the cell intersects the top line
                    line = 1;
                end
                
                % If any cells were found in the first frame, set firstFrame false
                % so future frames are checked for cells that intersect any line,
                % not just the top line
                if(jj == numLabels && counter > 0)
                    firstFrame = false;
                end
                
            % For frames other than the first frame (same as first frame,
            % but looks at every line, not just the top line.    
            else
                % Goes through each labeled region in the current frame, and finds
                % the line that the object intersects with 
                for line = 1:7
                    % Find their intersection
                    if(sum(currentRegion(lineCoordinate(line),:)) ~= 0)
                        % workingFrame = workingFrame | currentRegion;
                        counter = counter + 1;
                        % Breaks to preserve line, the line intersection
                        write = true;
                        break;
                    end
                    % If the cell is not touching any of the lines, set
                    % line = 0, so it is not included in the array
                    % cellInfo
                    if(line == 7)
                        write = false;
                        break;
                    end
                end
            end
            
            % To implement: check if the last cell is already touching the line
            % the current cell is touching (ie same cell touching same
            % line), if so, change write to false
            
            if(counter > 0 && write == true && line ~= 0)
                % Determines which lane the current cell is in
                [~, lane] = min(abs(laneCoords-cellCentroids(jj,1).Centroid(1)));
                
                % Now that line and lane are both known, checks the array
                % 'checkingArray' to see if the cell should be stored.  
                % There are two possibilities:
                %       1) The element of 'checking array' contains the 
                %       previous frame number. In this case, the frame 
                %       value in 'checkingArray' is updated, but the cell 
                %       is not stored.
                %       2) The element of 'checking array' does not contain 
                %       the previous frame number, or contains zero.  In 
                %       this case, the frame value is stored in 'checking
                %       array' and the cell is stored in the appropriate
                %       array in cellInfo.
                % In case 1:
                if(checkingArray(line,lane) == ii - 1 && (checkingArray(line,lane) ~= 0 || ii ~= 1))
                    % If the cell was in the same place as the line before
                    % And a cell was previously found at this line
                    % ~=0 since if the cell is the first to be found on
                    % line 1 in that lane, it will be zero (if in frame 1)
                    checkingArray(line,lane) = ii;
                else
                    % Also checks that the cell is not from the same frame
                    % as the previously found cell (cells should not be
                    % large enough to touch two lines simultaneously)
                    if(line ~=1)
                       if(checkingArray(line,lane) == checkingArray(line-1,lane)) 
                            continue;
                       end
                    end
                    % Save data about the cell:
                    % Frame number
                    cellInfo{lane}(laneIndex(lane),1) = ii;
                    % Cell number
                    cellInfo{lane}(laneIndex(lane),2) = counter;
                    % Line intersection
                    cellInfo{lane}(laneIndex(lane),3) = line;
                    % Saves the area of the cell in pixels
                    cellInfo{lane}(laneIndex(lane),4) = cellCentroids(jj,1).Area(1);
                    % Updates the checking array and lane index
                    checkingArray(line,lane) = ii;
                    laneIndex(lane) = laneIndex(lane) + 1;
                    % Update workingFrame
                    workingFrame = workingFrame | currentRegion;
                end
            end
            % Sets line = 0 so if the cell is not on a line, it is not
            % counted next loop
            line = 0;        
        end   
    end
    
    %% Frame postprocessing
    % Save the labeled image
    processedFrames(:,:,ii) = logical(workingFrame);
    
    if(WRITEVIDEO_FLAG == true)
        tempFrame = imoverlay(read(cellVideo,ii), bwperim(processedFrames(:,:,ii)), [1 1 0]);
        writeVideo(outputVideo, tempFrame);
    end
    
    % Check to see if the arrays in 'cellInfo' are filling.  If there are 
    % less than 10 more empty rows in any given array, estimate the number
    % of additional rows needed, based on the current filling and the 
    % number of frames remaining.  
    for jj = 1:16
        if((size(cellInfo{jj},2) - laneIndex(jj)) <= 10)
            vertcat(cellInfo{jj}, zeros(floor(((numFrames/ii-1)*size(cellInfo{jj},2))*1.1), 4));
        end
    end
    
    % Progress bar update
    if mod(ii, floor((numFrames)/100)) == 0
        progressbar([],[], (ii/(numFrames)))
    end
end

% Closes the video if it is open
if(WRITEVIDEO_FLAG)
    close(outputVideo);
end

%% Calls ProcessTrackingData to process the raw data and return
% transitTimeData, an nx7 array where n is the number of cells that
% transited completely through the device.  The first column is the total
% transit time, while columns 2-7 give the time taken to transit from
% constriction 1-2, 2-3, etc.
[transitTimeData] = ProcessTrackingData(checkingArray, framerate, cellInfo);
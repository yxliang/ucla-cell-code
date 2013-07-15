%% Cell Tacking

function [transitTimeData] = ProcessTrackingData(checkingArray, framerate, cellInfo)

% Tracks the cells
% Preallocation
% Occupied_row stores which of the lines in the current lane are currently
% occupied by a cell (for the frame being processed)
% occupied_lines = zeros(7,1);

% contactCount stores how many cells have touched a particular line in the
% lane.  The behavior is a little complicated to avoid issues when two
% cells independently enter the lane, but later 'merge' and are detected as
% only one cell.  
%   -It is initialized to zero.
%   -The first row (corresponding to line 1) is incremented by 1 each time 
%   a new cell object touches the first line.
%   - Later rows are incremented by copying the value from the row above
%   them.  For example, if a cell hits line 3, the value for line 3 becomes
%   the value currently in line 2.  Will only be counted as a cell if the
%   current value is less than the element above it, hopefully eliminating
%   blips that are found on lower lines.
%   - Line 1 is never incremented to be 2 larger than line 2.  This will
%   alleviate the issue that we have where line 1 has many blips.
% Each element stores the row where the data should be stored in the data 
% array.  Later filtering will eliminate any 'cell' that does not transit
% all the way through the device.

% laneData is an array containing the frame at which each cell is found
% at each line.  It is a (n x 7) array, where n is the number of cells.
% laneData contains data on every cell found, but will later be pared
% down to eliminate cells that didn't make it all the way through the
% device.  Each column corresponds to a line (1-7), and each row is a new 
% cell.  The numerical entry is the frame in which the cell hit the line,
% and will later be converted to times based on the framerate.
laneData = uint16(zeros(30,7));

% trackingData is a cell that contains the lane data for each lane
trackingData = cell(1,16);

% Goes through the data for each lane (1-16)
for lane = 1:16
    contactCount = zeros(7,1);
    if(any(checkingArray(:,lane) == 0))
        % Stores this lane's tracking data
        laneData = uint16(zeros(30,7));
        continue;
    else
        % For each cell in this lane's data
        for cellIndex = 1:size(cellInfo{lane},1)
            % If the cell is touching line 1, and the previous cell already
            % reached line 2
            currentLine = cellInfo{lane}(cellIndex,3);
            
            % Once all the cells are evaluated (current line is zero),
            if(currentLine == 0)
               break; 
            end
            
            if(currentLine == 1 && contactCount(1) == contactCount(2))
                % Increment the contact count
                contactCount(1) = contactCount(1) + 1;
                % Write the frame number to trackingData for that cell at
                % line 1
                laneData(contactCount(1), 1) = cellInfo{lane}(cellIndex,1);
            % If the cell is below line 1, and the contact count for the
            % previous line is greater than the current line (ie the cell
            % moved from the previous line), change the contactCount and
            % write the frame number to laneData 
            elseif(currentLine ~= 1 && contactCount(currentLine) < contactCount(currentLine-1))
                contactCount(currentLine) = contactCount(currentLine-1);
                laneData(contactCount(currentLine), currentLine) = cellInfo{lane}(cellIndex,1);
            end
            
            % Checks to make sure that the array is not full, adds more
            % space if necessary
            if(size(laneData,1) <= (contactCount(1) + 2))
               laneData = vertcat(laneData, uint16(zeros(10,7))); 
            end
        end
 
        % Stores this lane's tracking data, eliminating any cells that
        % didn't fully transit through the device.
        trackingData{lane} = laneData(all(laneData,2),:);
        laneData = uint16(zeros(30,7));
    end
end

transitTimeData = double(vertcat(trackingData{1:16}));

% Convert the data from frames into delta time values.  After this loop,
% column 1 will store the time at which the cell reached the line, and
% columns 2-7 will store the length of time the cell took to pass between
% the lines. For example, column 2 stores the amount of time it took for
% the cell to go from line 1 to line 2.

transitTimeData = 1 / (framerate*10^-3) * transitTimeData;

for ii = 1:6
   for jj = 1:size(transitTimeData,1)
        transitTimeData(jj,8-ii) = transitTimeData(jj,8-ii) - transitTimeData(jj,7-ii);
   end
end

% Overwrites the first column with the total time
for ii = 1:size(transitTimeData,1)
   transitTimeData(ii,1) = sum(transitTimeData(ii,2:7)); 
end
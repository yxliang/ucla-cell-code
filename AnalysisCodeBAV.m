%%% Bino Abel Varghese
%%% Code to track cells
%%% First part of the code

function cellSizes = AnalysisCodeBAV(processed, videoName)
close all;

disp(['Starting analysis for video ', videoName, '...']);
cellSizes = zeros(1, 10);
j = 1;
frameCount = size(processed, 3);

height = size(processed, 1);
width = size(processed, 2);

for frameIdx = 1:frameCount
    currFrame = processed(:,:,frameIdx);
    mask = imclearborder(currFrame(1:40,1:width));
    
    comps = bwconncomp(mask);
    if comps.NumObjects > 0
        s = regionprops(comps, 'Centroid', 'BoundingBox');%, 'MajorAxisLength', 'MinorAxis');
    
        for i = 1:length(s) 
            currCell = s(i);
            isUnconstricted = abs(currCell.Centroid(2) - 30) < 4;
            if(isUnconstricted)
                cellSizes(j) = (currCell.BoundingBox(3) + currCell.BoundingBox(4))/2;
                j = j+1;
                %cellSizes(j) = (currCell.MajorAxisLength + currCell.MinorAxisLength)/2;
            end
        end
    end
end
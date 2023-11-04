%% function isArtifact = checkArtifact()
%
% November 23, 2022
%
% Takes a list of xyPositions, computes the pairwise distance, and if
% there's a certain fraction of points that are within a certain threshold
% (currently assuming to be distanceThreshold =
% xyToSleepParams.stopVelocity_mm_per_s), then assume that this is an
% artifact.

% isArtifact = checkArtifact(xyPositions(eventStartIndex:lastHKindex,:),distanceThreshold);
function isArtifact = checkArtifact(xyPositions,distanceThreshold)

numPoints = size(xyPositions,1);
allDistances = pdist2(xyPositions,xyPositions);
%allDistances returns a matrix of size numPoints x numPoints
%If half of the positions are within one fly length of each other, then
%this list of xyPositions demonstrates an artifact.
numDistThreshold = ceil(2*(numPoints/2).^2);
numDistWithinThreshold = sum(allDistances(:)<distanceThreshold);
if(numDistWithinThreshold>numDistThreshold),
    %     isArtifact = 1;
    [numPointsInside,distFromCentroids]=numPointsInsideXYclusters(xyPositions, distanceThreshold);
    if(numPointsInside>(0.5*size(xyPositions,1))),
        isArtifact = 1;
    else,
        isArtifact = 0;
    end;
else,
    isArtifact = 0;
end;
display(['isArtifact = ' num2str(isArtifact) ', numDistThreshold = ' num2str(numDistThreshold) ...
    ', numDistWithinThreshold = ' num2str(numDistWithinThreshold) ', numFrames = ' num2str(numPoints)]);
display('');

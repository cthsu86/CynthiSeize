%% function numPointsInside=numPointsInsideXYclusters(xyPositions, distanceThreshold)
% January 8, 2022

function [numPointsInside,distFromCentroids]=numPointsInsideXYclusters(xyPositions, distanceThreshold)
numClusters = 2;
numPointsInside = 0;
distFromCentroids = 0;
% % if(0)
% [idx, clusterCentroids] = kmeans(xyPositions,numClusters); %size(xyPositions,1).^2);,'maxIter',100
% distFromCentroids = cell(numClusters,1);
% for(ci = 1:numClusters),
%     thisCentroid = clusterCentroids(ci,:);
%     thisClusterIndices = find(idx==ci);
%     thisClusterXY = xyPositions(thisClusterIndices,:);
%     distFromCentroid = sqrt(sum((thisClusterXY-repmat(thisCentroid,numel(thisClusterIndices),1)).^2,2));
%     distFromCentroids{ci} = distFromCentroid;
%     numPointsInside = numPointsInside+sum(distFromCentroid<distanceThreshold);
% % end;
% end;
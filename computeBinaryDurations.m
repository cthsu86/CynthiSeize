%% function computeBinaryDurations
% Returns an output vector, moveDurations, that is a vector containing all
% the durations over which
% Sequence of durations corresponds to the start and end indices listed as
% the second and third variable, respectively.

function [moveDurations,varargout] = computeBinaryDurations(movementBinary)

movementBinary = movementBinary(:);
isNanIndices = find(isnan(movementBinary));
movementBinary(isNanIndices) = 0;
% isNumIndices = find(~isnan(movementBinary));
% movementBinary = interp1

moveStartIndices = find(diff(movementBinary)==1)+1;
%If the first non-nan value of noMovemementBinary is 1 (first value is
%probably a NaN because of the differential).
firstNonNanIndex = find(~isnan(movementBinary),1);
% display(size(moveStartIndices));
if(movementBinary(firstNonNanIndex)),
    moveStartIndices = [firstNonNanIndex; moveStartIndices];
end;
moveEndIndices = find(diff(movementBinary)==-1);
if(movementBinary(end)),
    moveEndIndices = [moveEndIndices; numel(movementBinary)];
end;

% try,
moveDurations = moveEndIndices-moveStartIndices+1;
% catch,
%     display('mrp.');
% end;

varargout{1} = moveStartIndices;
varargout{2} = moveEndIndices;
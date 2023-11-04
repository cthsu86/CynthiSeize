%% function sleepOnly_saveSingleCohort()
%
% March 11, 2022
%
% Based on sleepAndSeizure_saveSingleCohort_separateMats_v7. Designed to be
% called by the wakeAndDeath_byCohort subroutine in the event that
% sleepAndSeizure_saveSingleCohort_separateMats_v6 was run, which saves a
% matrix full of NaNs instead of actual sleep data.

function isSleeping_array2save = sleepOnly_saveSingleCohort(rootdir,fileNamesByDay,ZT0_clockHour)
stringToReplace = 'Arena 1';
arenaNums = [1:24]; %[1:24]; %[1:6:19; 2:6:20; 3:6:21; 4:6:22; 5:6:23; 6:6:24];
arenasToExclude = []; %2 16]; %Exclude dead arenas.

% Names of files saved by the script.
% day1fileName(1:14): Assumes that the first 14 characters follow the
% format 'Track-yyyymmdd'.
%% ============================================
cd(rootdir);

for(ai = 1:numel(arenaNums)),
    thisArenaNum = arenaNums(ai);
    if(~ismember(thisArenaNum,arenasToExclude)),
        isSleeping_thisArena = consolidateMultiDayArenaData(fileNamesByDay,stringToReplace,num2str(thisArenaNum)); %, ZT0_clockHour);
        if(~exist('isSleeping_array2save','var')),
            isSleeping_array2save = NaN(numel(isSleeping_thisArena),numel(arenaNums));
        end;
        if(size(isSleeping_array2save,1)<isSleeping_thisArena),
            %Need to reallocate the matrix.
            temp = isSleeping_array2save;
            clear isSleeping_array2save;
            isSleeping_array2save = NaN(size(allTimepoints_array2save));
            isSleeping_array2save(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
        end;
        isSleeping_array2save(1:numel(isSleeping_thisArena),thisArenaNum) = isSleeping_thisArena;
    end;
end;
% 
% save(seizure_matName,'-mat','allTimepoints_array2save','timestamps_array2save','fps','ZT0_clockHour','xPosition_array2save','yPosition_array2save',...
%     'xyToSleepParams','fileNamesByDay','firstTimestampInFile', '-v7.3');
% save(sleep_matName,'-mat','isSleeping_array2save','timestamps_array2save','fps','ZT0_clockHour','xPosition_array2save','yPosition_array2save',...
%     'xyToSleepParams','firstTimestampInFile', '-v7.3');
% % save(binnedSleep_matname,'fileNamesByDay','-mat','binnedSleepMat','binnedSleep_ZTtime', '-v7.3');
% % save(timestamps_matname,'-v7.3','timestamps_array2save');

%%========================================================================
%% function consolidateMultiDayArenaData
% To be run on a single arena, given the file name format of multiple days.
function isSleeping_thisArena = consolidateMultiDayArenaData(fileNamesByDay,stringToReplace,arenaNumString)
dataPointsForArena = 0;
dataByDay = cell(size(fileNamesByDay,1),1);
firstTimeStampInFile = NaN(size(fileNamesByDay,1),1);

for(di = 1:size(fileNamesByDay,1)),
    thisDayFileFormat = fileNamesByDay{di,1};
    thisDayFileName = strrep(thisDayFileFormat,stringToReplace,['Arena ' arenaNumString]);
    if(exist(thisDayFileName,'file')),
        display(['Reading ' thisDayFileName]);
        thisDayData = sleepFromSingleWell_simple(thisDayFileName); %, fps); %, eventsPer30min_threshold);
        isNumIndices = find(~isnan(thisDayData(:,1)));
        %5 columns: time, x, y, isSleeping, isHyperkinetic
        dataByDay{di,1} = thisDayData(isNumIndices,:);
        dataPointsForArena = dataPointsForArena+numel(isNumIndices); %size(thisDayData,1);
        firstTimeStampInFile(di) = thisDayData(isNumIndices(1),1);
    end;
end;
isSleeping_thisArena_unsorted = NaN(dataPointsForArena,1);
unsortedTimestamps = NaN(dataPointsForArena,1);

offsetIndex = 1;
for(di = 1:size(fileNamesByDay,1)),
    thisDayData = dataByDay{di,1};
    endPointIndex = (offsetIndex+size(thisDayData,1)-1);
    %     display(size(thisDayData))
    if(size(thisDayData,1)>0),
        %thisDayData columns:
        %1 = datenum (units of days)
        %4 = isSleeping
        %6 = isMoving
        %2 = xPosition
        %y = yPosition
        isSleeping_thisArena_unsorted(offsetIndex:endPointIndex) = thisDayData(:,4);%(:,[1 4:6]);
        unsortedTimestamps(offsetIndex:endPointIndex) = thisDayData(:,1);
        offsetIndex = endPointIndex+1;
    end;
end;

[sortedDateNums, sortedIndices] = sort(unsortedTimestamps,'ascend');

isSleeping_thisArena = isSleeping_thisArena_unsorted(sortedIndices,:);

%% function sleepAndSeizure_saveSingleCohort_separateMats_v7
% Estimated runtime: ~5 minutes 
%
% March 11, 2022
%
% v7: corrected thee error in which isSleeping was not actually being saved either?
% v6: XY data was actually not being saved - columns 4 and 5, (isSleeping,
% isSeizure) were being saved instead?
% v5: ZT timestamp debug, also Octave compatible
% v3: also saves XY data, which we will need to distinguish tracking
% artifacts from seizures.
% 
% Unlike v1, which saves two *.mat files, v2 saves three:
% 1) hyperkineticData_byTimepoint
% 2) sleepData_byTimepoint
% 3) binnedSleepData
% - Note: fractional bins at the start and end of the trial are normalized to the faction of the bin available.
% Some optimizations in place to reduce the amount of time that the subsequent script (quantifySeizures_singleCondition_multiCohort_v2.m) needs to load
% the data saved by this script.

function sleepAndSeizure_saveSingleCohort_separateMats_v7()
try,
pkg load statistics;
catch,
end;

close all;
rootdir = 'D:\Video Tracking\20231024 MB122B+GtACR+ATR+Picro\Export Files';

fileNamesByDay = {...
    'Track-20231024 MB122B+GtACR+ATR+Picro-Trial     1-1-Subject 1.mat'}
%'Track-20210809 tko, tim, timtko in control-Trial     1-Arena 1-Subject 1.mat'};
%     'Track-20210809 tko, tim, timtko in control-Trial     2-Arena 2-Subject 1.mat';
%     'Track-20210809 tko, tim, timtko in control-Trial     3-Arena 1-Subject 1.mat';
%     'Track-20210809cont tko, tim, timtko in control-Trial     1-Arena 1-Subject 1.mat';
%     'Track-20210809cont tko, tim, timtko in control-Trial     2-Arena 1-Subject 1.mat'};
stringToReplace = '-1-';
arenaNums = [1:48]; %[1:24]; %[1:6:19; 2:6:20; 3:6:21; 4:6:22; 5:6:23; 6:6:24];
arenasToExclude = []; %Exclude dead arenas.
minsPerBin = 30;
ZT0_clockHour = 9; %Can use fractions of hours (for instance, 10.25 is lights on at 10:15).

% Names of files saved by the script.
% day1fileName(1:14): Assumes that the first 14 characters follow the
% format 'Track-yyyymmdd'.
day1fileName = fileNamesByDay{1};
seizure_matName = [day1fileName(1:14) '_multiDay_allArenas_hyperkineticData_byTimepoint.mat'];
sleep_matName = strrep(seizure_matName,'hyperkineticData','sleepData');
binnedSleep_matname  = strrep(seizure_matName,'_hyperkineticData_byTimepoint',[num2str(minsPerBin) 'minBinnedSleepData']);
% timestamps_matname = strrep(seizure_matName,'hyperkineticData_byTimepoint.mat','allTimestamps.mat');

% User does not have to change anything below this line.
%% ============================================
cd(rootdir);

% maxArenaNum = max(arenaNums(:));
% In v2 of this script, using containers.Map() instead of cell arrays. 
% allTimepoints_array2save = cell(maxArenaNum,1);
% binned_array2save = cell(maxArenaNum,1);
% hrPerTimepoint_array2save = cell(maxArenaNum,1);
% hkAllTimepoints_map2save = containers.Map(1:maxArenaNum,cell(maxArenaNum,1));
% sleepAllTimepoints_map2save = containers.Map(1:maxArenaNum,cell(maxArenaNum,1));
% Set a "binnedSleep" matrix later after we have figured out how many data
% points are being saved for all days.

hrsPerBin = minsPerBin/60;

for(ai = 1:numel(arenaNums)),
    thisArenaNum = arenaNums(ai);
    if(~ismember(thisArenaNum,arenasToExclude)),
        %        figure(ai);
        [timeSleepSeizureData,binnedSleepSeizureData,xyToSleepParams,firstTimestampInFile,fps] ...
            = consolidateMultiDayArenaData(fileNamesByDay,stringToReplace,num2str(thisArenaNum),hrsPerBin, ZT0_clockHour);
        %binnedSleepSeizureData: (# of bins) x (# of flies)
        % Column 1: Clock (not ZT) time
        % 
        if(~exist('binnedSleepMat','var')),
            binnedSleepMat = NaN(size(binnedSleepSeizureData,1),numel(arenaNums));
            binnedSleep_ZTtime = NaN(size(binnedSleepMat));
            allTimepoints_array2save = NaN(size(timeSleepSeizureData,1),numel(arenaNums));
            isSleeping_array2save = NaN(size(timeSleepSeizureData,1),numel(arenaNums));
            timestamps_array2save = NaN(size(timeSleepSeizureData,1),numel(arenaNums));
            xPosition_array2save = NaN(size(timeSleepSeizureData,1),numel(arenaNums));
            yPosition_array2save = NaN(size(timeSleepSeizureData,1),numel(arenaNums));
        end;
        if(size(allTimepoints_array2save,1)<size(timeSleepSeizureData,1)),
            %Need to reallocate the matrix.
            temp = allTimepoints_array2save;
            clear allTimepoints_array2save;
            allTimepoints_array2save = NaN(size(timeSleepSeizureData,1),size(temp,2));
            allTimepoints_array2save(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = isSleeping_array2save;
            clear isSleeping_array2save;
            isSleeping_array2save = NaN(size(allTimepoints_array2save));
            isSleeping_array2save(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = timestamps_array2save;
            clear timestamps_array2save;
            timestamps_array2save = NaN(size(allTimepoints_array2save));
            timestamps_array2save(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp; 
            temp = xPosition_array2save;
            clear xPosition_array2save;
            xPosition_array2save = NaN(size(allTimepoints_array2save));
            xPosition_array2save(1:size(temp,1),1:size(temp,2)) = temp;
            
            clear temp; 
            temp = yPosition_array2save;
            clear yPosition_array2save;
            yPosition_array2save = NaN(size(allTimepoints_array2save));
            yPosition_array2save(1:size(temp,1),1:size(temp,2)) = temp;
            
        end;
        if(size(binnedSleepMat,1)<size(binnedSleepSeizureData,1)),        
            temp = binnedSleepMat;
            clear binnedSleepMat;
            binnedSleepMat=NaN(size(binnedSleepSeizureData,1),size(temp,2));
            binnedSleepMat(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = binnedSleep_ZTtime;
            clear binnedSleep_ZTtime;
            binnedSleep_ZTtime = NaN(size(binnedSleepMat));
            binnedSleep_ZTtime(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
        end;
        binnedSleepMat(1:size(binnedSleepSeizureData,1),ai) = binnedSleepSeizureData(:,3)';
        binnedSleep_ZTtime(1:size(binnedSleepSeizureData,1),ai) = binnedSleepSeizureData(:,2)'; %thisArena_ZTtime; %binnedSleepSeizureData(:,2);
        allTimepoints_array2save(1:size(timeSleepSeizureData,1),ai) = timeSleepSeizureData(:,3);
        timestamps_array2save(1:size(timeSleepSeizureData,1),ai) = timeSleepSeizureData(:,1);
        isSleeping_array2save(1:size(timeSleepSeizureData,1),ai) = timeSleepSeizureData(:,2);
        xPosition_array2save(1:size(timeSleepSeizureData,1),ai) = timeSleepSeizureData(:,5);
        yPosition_array2save(1:size(timeSleepSeizureData,1),ai) = timeSleepSeizureData(:,6);
    end;
end;

save(seizure_matName,'-mat','allTimepoints_array2save','timestamps_array2save','fps','ZT0_clockHour','xPosition_array2save','yPosition_array2save',...
    'xyToSleepParams','fileNamesByDay','firstTimestampInFile', '-v7.3');
save(sleep_matName,'-mat','isSleeping_array2save','timestamps_array2save','fps','ZT0_clockHour','xPosition_array2save','yPosition_array2save',...
    'xyToSleepParams','firstTimestampInFile', '-v7.3');
save(binnedSleep_matname,'fileNamesByDay','-mat','binnedSleepMat','binnedSleep_ZTtime', '-v7.3');
% save(timestamps_matname,'-v7.3','timestamps_array2save');

%%========================================================================
%% function consolidateMultiDayArenaData
% To be run on a single arena, given the file name format of multiple days.
function [timeSleepSeizureData, binnedSleepSeizureData,xyToSleepParams,firstTimeStampInFile,fps]= consolidateMultiDayArenaData(fileNamesByDay,stringToReplace,arenaNumString,hrsPerBin, ZT0_clockHour);
dataPointsForArena = 0;
dataByDay = cell(size(fileNamesByDay,1),1);
firstTimeStampInFile = NaN(size(fileNamesByDay,1),1);

for(di = 1:size(fileNamesByDay,1)),
    thisDayFileFormat = fileNamesByDay{di,1};
    thisDayFileName = strrep(thisDayFileFormat,stringToReplace,['-' arenaNumString '-']);
    if(exist(thisDayFileName,'file')),
        display(['Reading ' thisDayFileName]);
        [thisDayData, xyToSleepParams,fps] = sleepFromSingleWell_simple(thisDayFileName); %, fps); %, eventsPer30min_threshold);
        isNumIndices = find(~isnan(thisDayData(:,1)));
        %5 columns: time, x, y, isSleeping, isHyperkinetic
        dataByDay{di,1} = thisDayData(isNumIndices,:);
        dataPointsForArena = dataPointsForArena+numel(isNumIndices); %size(thisDayData,1);
        firstTimeStampInFile(di) = thisDayData(isNumIndices(1),1);
%         if(di==size(fileNamesByDay,1))
%             display('eep');
%         end;
    end;
end;
timeSleepSeizureData = NaN(dataPointsForArena,6);
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
        timeSleepSeizureData(offsetIndex:endPointIndex,:) = thisDayData(:,[1 4:6 2:3]);%(:,[1 4:6]);
%         %date (in datenum, which is units of days), isSleeping,
%         %isHyperkinetic,isMoving
        offsetIndex = endPointIndex+1;
    end;
end;

[sortedDateNums, sortedIndices] = sort(timeSleepSeizureData(:,1),'ascend');

timeSleepSeizureData = timeSleepSeizureData(sortedIndices,:);

% try,
ZT0_day0_vec = datevec(sortedDateNums(1));
% catch,
%    display('meep');
% end;
floored_ZT0 = floor(ZT0_clockHour);
ZT0_day0_vec(4) = floored_ZT0;
if(floored_ZT0~=ZT0_clockHour),
    minutesOffset = (ZT_clockHour-floored_ZT0)*60;
else
    minutesOffset = 0;
end;
ZT0_day0_vec(5) = minutesOffset;
ZT0_day0_vec(6) = 0;

ZT_day0_datenum = datenum(ZT0_day0_vec);

% Can we convert sortedDateNums into a more sane axis label somehow?
% sortedDateVec = datevec(sortedDateNums);
% hourPerTimepoint = sortedDateVec(:,4)+sortedDateVec(:,5)/60;
% offsetByDay = sortedDateNums-sortedDateNums(1);
% ZTtime_offsetByDay_v1 = hourPerTimepoint+(offsetByDay+1)*24-ZT0_clockHour; %floor(ZTtime/24)*24;
ZTtime_offsetByDay_v1 = (sortedDateNums-ZT_day0_datenum)*24;
% 
% ZTtime = hourPerTimepoint-ZT0_clockHour;
% negativeIndices = find(ZTtime<0);
% ZTtime(negativeIndices) = ZTtime(negativeIndices)+24;
% ZTtime_offsetByDay_v2 = ZTtime+offsetByDay*24; %floor(ZTtime/24)*24;

% %While hourPerTimepoint will be equal to the hour on the first day, we want
% %the data from each subsequent day to be 24 hours later. In other words,
% %'hourPerTimepoint_offsetByDay' will have a max value of 72 hours instead of 24. 
% %
% % Previously, hourPerTimepoint_offsetByDay was computed relative to the first timepoint 
% %hourPerTimepoint_offsetByDay = floor((sortedDateNums-sortedDateNums(1))*24);
% %
% % However, a better idea for multi-cohort comparison would be to compute it relative to a 'complete' bin.
% minuteOffset = ZT0_clockHour-floor(ZT0_clockHour);
% timestamp_min_withOffset = sortedDateVec(:,5)*60-minuteOffset;
% deltaMinute = diff(timestamp_min_withOffset);
% firstFrameIndexWithCompleteBin = find(deltaMinute<0,'first');
% % binnedHourPerTimepoint

binned_HourPerTimepoint_offsetByDay = floor(ZTtime_offsetByDay_v1/hrsPerBin)*hrsPerBin;
[C,IA,IC] = unique(binned_HourPerTimepoint_offsetByDay,'stable');

binnedSleepSeizureData = NaN(numel(C),3);
for(bi = 1:numel(C)),
    if(bi<numel(C)),
        lastIndexInBin = IA(bi+1)-1;
    else
        lastIndexInBin = numel(binned_HourPerTimepoint_offsetByDay);
    end;
    firstIndexInBin = IA(bi);
    binnedSleepSeizureData(bi,3) = nansum(timeSleepSeizureData(firstIndexInBin:lastIndexInBin,2))/(lastIndexInBin-firstIndexInBin+1);
    binnedSleepSeizureData(bi,2) = binned_HourPerTimepoint_offsetByDay(IA(bi));
    binnedSleepSeizureData(bi,1) = ZTtime_offsetByDay_v1(IA(bi)); %hourPerTimepoint(IA(bi));
end;
% hourPerTimepoint = [hourPerTimepoint hourPerTimepoint_offsetByDay];
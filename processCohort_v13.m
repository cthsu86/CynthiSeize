%% function processCohort_v13(rootdir_line,inputMat_line,arenaNums_line,numEvents,secondsPerInterval,minBtwnSeizures,...);
%
% December 16, 2022
%
% v13: Mathematically identical to v11, but with extra text outputs in
% keeping with what Vishnu's statistical analysis collaborators want:
% -- Fly ID, Treatment Group, seizure? (binary), Duration of seizure, HK events per seizure
% -- There should be 72 rows in this dataset (18 flies per group x first 4 days of recording)
%
% v11: hoursToAnalyze
%
% v9: v8 had a bug. =( Trying to restore it back to v6 functionality in a
% sensible way.
%
% v8: Unlike v7, which basically checked individual seizures to make sure
% they exceeded the minEventsPerSeizure before setting them as a seizure,
% this version of the code only performs the check that minEventsPerSeizure
% is exceeded after successive seizures have been consolidated.
%
% v6: Based on v5, but designed to process input from
% sleepAndSeizure_saveSingleCohort_separateMats_v3 which it receives from the parent function, quantifySeizures_multiCondition_multiCohort_v10.
% Modified to utilize XY positions to distinguish tracking artifacts from
% actual seizures.
%
% Contains internal subroutine processArena.
%
% v5: based on v4, from December 10, 2021, but with the addition of seizure in terms of minutes, rather than number of seizures.
% Based on processCohort_v2, from October 17, 2021 (moved to its own *.m file)
% Like v2, seizure continuations are detected via for loop (vs v2, where
% seizures are detected via array).
%
% Outputs:
% - seizuresPerDay_forCohort (array with # of elements equal to # of arenas in cohort)
% - Three histogram distributions (duration, # of events/seizure, and # events/min of seizure
% - Also a two column array of seizure duration vs # of hyperkinetic events
% Want to also open a *_eventList.txt file to write timestamps of seizure
% events to (and maybe the rest of the features).
function [seizureMat,seizuresPerDay_forCohort, seizureDurationHist,hkPerSeizureHist,hkPerMinHist, interHKeventInterval_fullCohortHist,...
    interseizure_fullCohortHist,binnedSleep_ZTtime, binnedSleepMat, binnedSeizureMat, binnedHkEventMat, binnedSeizureTimeMat, ...
    firstLastTimestamp_offsetByDay] = processCohort_v13(rootdir_line,inputMat_line,arenaNums_line,numEvents,secondsPerInterval,minBtwnSeizures,...
    seizureDurationHistogram_bins_sec,hkPerSeizure_bins,seizure_hkPerMin_histogramBins,interHKeventInterval_bins_sec,interseizureInterval_bins_hrs,...
    seizureParamSuffix,outputSeizureListsPerVideo, minEventsPerSeizure, hoursToAnalyze,sleepDeathCutoff_hrs);
% Version 10 is meant to correct the error in which zero seizures are being
% saved to the output variable which, in the parent function
% quantifySeizures_mutiCondition_multiCohort_v16.m, is referred to as:
%         %--- Start of dumb giant output list for processCohort function----
%         [seizureMat,seizuresPerDay, seizureDurationHist,hkPerSeizureHist,hkPerMinHist, interHKeventInterval_singleCohortHist, ...
%             interseizureInterval_singleCohortHist,
%             binnedSleep_ZTtime_singleCohort,binnedSleepMat_singleCohort, binnedSeizureMat_singleCohort,
%% binnedSleep_ZTtime_singleCohort - in this function, this is equivalent to the binnedSeizureMat variable

rootdir_line = rootdir_line{1,1};
inputMat_line = inputMat_line{1,1};
arenaNums_line = arenaNums_line{1,1};

display(rootdir_line)
cd(rootdir_line(1:(end-2)));
matInputNameRoot = inputMat_line(1:(end-2));
A = load([matInputNameRoot '_hyperkineticData_byTimepoint.mat']);
hyperkinetic_allArenas = A.allTimepoints_array2save;
% xy_allArenas = hyperkinetic_allArenas(:,5:6);
% hyperkinetic_allArenas = hyperkinetic_allArenas(:,1:4);
timestamps_allArenas = A.timestamps_array2save; %timestamps are saved strictly in terms of datenum.
xPositions_allArenas = A.xPosition_array2save;
yPositions_allArenas = A.yPosition_array2save;

%There is a slightly different timestamp saved for each arena.
%Because of the way the data is saved by group, some of the

ZT0_clockHour = A.ZT0_clockHour;
xyToSleepParams = A.xyToSleepParams;
distanceThreshold = xyToSleepParams.stopVelocity_mm_per_s;
%'fileNamesByDay','firstTimeStampInFile'
fileNamesByDay = A.fileNamesByDay;
firstTimeStampInFile = A.firstTimestampInFile;
[firstTimeStampInFile, sortedIndices] = sort(firstTimeStampInFile,'ascend');
%If the previous video files were entered in the wrong order.
fileNamesByDay = fileNamesByDay(sortedIndices);
interframeInterval_sec = nanmean(diff(timestamps_allArenas(:,1))*24*3600);
fps = 1/interframeInterval_sec;
clear A;

% This next block of code is added to deal with the issue with partial 30
% min bins.
% firstTimestamp = min(timestamps_allArenas(:));
% lastTimestamp = max(timestamps_allArenas(:));
% ZT0_day0_vec = datevec(firstTimestamp);
% floored_ZT0 = floor(ZT0_clockHour);
% % datevec: Year, Month, Day, Hour
% ZT0_day0_vec(4) = floored_ZT0;
% if(floored_ZT0~=ZT0_clockHour),
%     minutesOffset = (ZT_clockHour-floored_ZT0)*60;
% else
%     minutesOffset = 0;
% end;
% ZT0_day0_vec(5) = minutesOffset;
% ZT0_day0_vec(6) = 0
% ZT0_day0_datenum = datenum(ZT0_day0_vec);
% firstTimestamp_offsetByDay = firstTimestamp-ZT0_day0_datenum;
% lastTimestamp_offsetByDay = lastTimestamp-ZT0_day0_datenum;

arenaList = str2num(arenaNums_line);
numArenas = numel(arenaList);
data2write_byDay_byArena = cell(size(fileNamesByDay,1),numArenas);
%data2write_byDay_byArena will store the data to write so that we don't have to
%repeatedly open and close the file to write.

A = load([matInputNameRoot '30minBinnedSleepData.mat']);
binnedSleepMat = A.binnedSleepMat;
binnedSleep_ZTtime = A.binnedSleep_ZTtime;
binnedSleepMat = binnedSleepMat(:,arenaList);
hrsPerBin = (max(binnedSleep_ZTtime(:))-min(binnedSleep_ZTtime(:)))/(size(binnedSleep_ZTtime,1)-1); %nanmean(diff(binnedSleep_ZTtime(:,1)));
numBinsToAnalyze = hoursToAnalyze/hrsPerBin;

if(numBinsToAnalyze>size(binnedSleep_ZTtime,1)),
    numBinsToAnalyze = size(binnedSleep_ZTtime,1);
end;
binnedSleep_ZTtime = binnedSleep_ZTtime(1:numBinsToAnalyze,arenaList);
binnedSleepMat = binnedSleepMat(1:numBinsToAnalyze,:);
zeroIndices = find(binnedSleep_ZTtime==0);
binnedSleep_ZTtime(zeroIndices) = NaN;
binnedSleepMat(zeroIndices) = NaN;
binnedSeizureMat = NaN(size(binnedSleepMat));
binnedSeizureTimeMat = NaN(size(binnedSleepMat));
binnedHkEventMat = NaN(size(binnedSleepMat));

seizuresPerDay_forCohort = NaN(numArenas,1);
seizureDurationHist = zeros(size(seizureDurationHistogram_bins_sec));
hkPerSeizureHist = zeros(size(hkPerSeizure_bins));
hkPerMinHist = zeros(size(seizure_hkPerMin_histogramBins));
interHKeventInterval_fullCohortHist = zeros(size(interHKeventInterval_bins_sec));
interseizure_fullCohortHist = zeros(size(interseizureInterval_bins_hrs));
seizureMat = cell(numArenas,1);
firstLastTimestamp_offsetByDay = NaN(numArenas,3);

for(ai = 1:numArenas),
    timestamps_thisArena = timestamps_allArenas(:,arenaList(ai));
    isHyperkinetic = hyperkinetic_allArenas(:,arenaList(ai));
    
    firstNonNanTimestamp = find(~isnan(timestamps_thisArena),1,'first');
    lastTimeToAnalyze = timestamps_thisArena(firstNonNanTimestamp)+hoursToAnalyze/24;
    lastIndexToAnalyze = find(timestamps_thisArena>lastTimeToAnalyze,1,'first')-1;
    if(numel(lastIndexToAnalyze)==0)
        lastIndexToAnalyze = numel(timestamps_thisArena);
    end;
    
    ZT0_day0_vec = datevec(timestamps_thisArena(firstNonNanTimestamp));
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

    timestamps_thisArena_offsetByDay = (timestamps_thisArena(1:lastIndexToAnalyze)-ZT_day0_datenum)*24;
    lastNumIndex = find(~isnan(timestamps_thisArena_offsetByDay),1,'last');
    if(numel(lastNumIndex)==0),
        lastNumIndex = numel(timestamps_thisArena_offsetByDay);
    end;
    firstLastTimestamp_offsetByDay(ai,1) = timestamps_thisArena_offsetByDay(1);
    firstLastTimestamp_offsetByDay(ai,2) =timestamps_thisArena_offsetByDay(lastNumIndex);
    firstLastTimestamp_offsetByDay(ai,3) =ZT_day0_datenum;
    [seizuresPerDay, seizureOnsetDurationNumHK,interHKeventInterval_thisArenaHist, hyperkinetic_startTimestamps,isSeizure] ...
        = processArena(isHyperkinetic(1:lastIndexToAnalyze),timestamps_thisArena(1:lastIndexToAnalyze), ...
        numEvents,secondsPerInterval,minBtwnSeizures, interHKeventInterval_bins_sec,...
        [xPositions_allArenas(1:lastIndexToAnalyze,arenaList(ai)) yPositions_allArenas(1:lastIndexToAnalyze,arenaList(ai))],...
        distanceThreshold,minEventsPerSeizure);
    
    
    % -- Fly ID, Treatment Group, seizure? (binary), Duration of seizure, HK events per seizure
    % -- There should be 72 rows in this dataset (18 flies per group x first 4 days of recording)
    %
    seizuresPerDay_forCohort(ai) = seizuresPerDay;
    seizureMat{ai} = seizureOnsetDurationNumHK;
    if(size(seizureOnsetDurationNumHK,1)>0),
        seizureDurations = seizureOnsetDurationNumHK(:,2)*24*3600;
        seizureDurationHist = seizureDurationHist+hist(seizureDurations,seizureDurationHistogram_bins_sec);
        hkPerSeizureHist_thisArena = hist(seizureOnsetDurationNumHK(:,3),hkPerSeizure_bins);
        hkPerSeizureHist = hkPerSeizureHist+hkPerSeizureHist_thisArena;
        hkPerMin = seizureOnsetDurationNumHK(:,3)./(seizureDurations/60);
        hkPerMinHist = hkPerMinHist+hist(hkPerMin,seizure_hkPerMin_histogramBins);
        
        display(['seizureOnsetDurationNumHK: ' num2str(sum(~isnan(seizureOnsetDurationNumHK(:,1))))]);
        display(['hkPerMinHist: ' num2str(sum(hkPerSeizureHist_thisArena))]);
        
        interHKeventInterval_fullCohortHist = interHKeventInterval_fullCohortHist + interHKeventInterval_thisArenaHist;
        % Compute interseizure interval from the onset.
        interseizureInterval = diff(seizureOnsetDurationNumHK(:,1));
        [interseizureHist,~] = hist(interseizureInterval*24,interseizureInterval_bins_hrs);
        if(min(size(interseizureHist))==0),
        else,
            interseizure_fullCohortHist = interseizure_fullCohortHist+interseizureHist;
        end;
        
        %Lastly, want to bin the seizure times.
        ZTtime_offsetByDay = (seizureOnsetDurationNumHK(:,1)-ZT_day0_datenum)*24;
        hk_ZTtime_offsetByDay = (hyperkinetic_startTimestamps-ZT_day0_datenum)*24;
        %         timestamps_thisArena_offsetByDay = (timestamps_thisArena-ZT_day0_datenum)*24;
        %         firstLastTimestamp_offsetByDay(ai,1) =timestamps_thisArena_offsetByDay(1);
        %         firstLastTimestamp_offsetByDay(ai,2) =timestamps_thisArena_offsetByDay(end);
        %         firstLastTimestamp_offsetByDay(ai,3) =ZT_day0_datenum;
        
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
        binned_seizureOnsetTime_offsetByDay = floor(ZTtime_offsetByDay/hrsPerBin)*hrsPerBin;
        binned_hkTime_offsetByDay = floor(hk_ZTtime_offsetByDay/hrsPerBin)*hrsPerBin;
        binned_timestamps_thisArena_offsetByDay = floor(timestamps_thisArena_offsetByDay/hrsPerBin)*hrsPerBin;
        %binned_seizureOnsetTime_offsetByDay is an ordered list of every
        %         %seizure, where the values represent the bin of the onset time.
        %         binnedSeizureMat = NaN(size(binnedSleep_ZTtime,1),numArenas);
        %         if(~isempty(binned_seizureOnsetTime_offsetByDay)),
        %             display('help.');
        %         end;
        for(bi = 1:size(binnedSleep_ZTtime,1)),
            thisBinTime = binnedSleep_ZTtime(bi,1);
            numSeizuresInBin = nansum(binned_seizureOnsetTime_offsetByDay==thisBinTime);
            binnedSeizureMat(bi,ai) = numSeizuresInBin;
            binnedHkEventMat(bi,ai) = nansum(binned_hkTime_offsetByDay==thisBinTime);
            thisBin_timestampIndices = find(binned_timestamps_thisArena_offsetByDay==thisBinTime);
            minutesSeizureInBin = nansum(isSeizure(thisBin_timestampIndices))/fps/60;
            binnedSeizureTimeMat(bi,ai) = minutesSeizureInBin;
            if(numSeizuresInBin==0 && minutesSeizureInBin>0),
            end;
        end;
        
        %we want to output a list of seizures for each day (video file).
        for(di=1:size(firstTimeStampInFile,1)),
            if(di<size(firstTimeStampInFile,1)),
                seizureIndicesInVideo = find(seizureOnsetDurationNumHK(:,1)<firstTimeStampInFile(di+1) & seizureOnsetDurationNumHK(:,1)>=firstTimeStampInFile(di));
            else,
                seizureIndicesInVideo = find(seizureOnsetDurationNumHK(:,1)>=firstTimeStampInFile(di));
            end;
            hoursElapsed = (seizureOnsetDurationNumHK(seizureIndicesInVideo,1)-firstTimeStampInFile(di))*24;
            data2save = NaN(size(hoursElapsed,1),6); %Hours, Minutes, Seconds, Arena, duration, numHK
            data2save(:,1) = floor(hoursElapsed);
            minutesOffset = (hoursElapsed-floor(hoursElapsed))*60;
            data2save(:,2) = floor(minutesOffset);
            data2save(:,3) = (minutesOffset-floor(minutesOffset))*60;
            data2save(:,4) = arenaList(ai);
            data2save(:,6) = seizureOnsetDurationNumHK(seizureIndicesInVideo,3);
            data2save(:,5) = seizureOnsetDurationNumHK(seizureIndicesInVideo,2)*24*3600;
            data2write_byDay_byArena{di,ai} = data2save;
%             data2write_byDay_byArena = cell(size(fileNamesByDay,1),numArenas);
        end;
    end;
    %     end;
end; %Close the numArenas loop.

% data2write_byFlyAndTrueDayPerRow = zeros(numArenas*ceil(hoursToAnalyze/24),5);
data2write_byFly = cell(numArenas,1);
% row2save = 1;
% firstTimestampOfExperiment = firstTimeStampInFile(1);
if(outputSeizureListsPerVideo),
    for(di = 1:size(fileNamesByDay,1)), %data2write_byDay_byArena,1)),
        if(~isempty(strfind(fileNamesByDay{di},'Arena 1'))),
            thisDayFileName = strrep(fileNamesByDay{di},'Arena 1-Subject 1.mat',[seizureParamSuffix '.txt']);
        else,
            thisDayFileName = strrep(fileNamesByDay{di},'-1-Subject 1.mat',[seizureParamSuffix '.txt']);
        end;
        %---------- Original text file output for seizures detection.
        thisDay_fID =fopen(thisDayFileName,'w');
        fprintf(thisDay_fID,['First timestamp: ' datestr(firstTimeStampInFile(di)) char(10) ...
            'Hour Min Sec Arena Duration #ofHKevents' char(10)]);
        for(ai = 1:numArenas),
            dataSaved_thisArena = data2write_byDay_byArena{di,ai};
            numLines = size(dataSaved_thisArena,1);
            if(isempty(dataSaved_thisArena)||numLines==0),
                %                 numSeizures = 0;
                %                 totalSeizureDuration = 0;
                %                 numHKevents = 0;
                %                 data2write_byFlyAndTrueDayPerRow(ri,
            else,
                seizuresListWithTrueDayAssignment = NaN(numLines,3); %
                seizuresListWithTrueDayAssignment(:,1) = firstTimeStampInFile(di)+(dataSaved_thisArena(:,1)/24+dataSaved_thisArena(:,2)/60+dataSaved_thisArena(:,3)/3600)-firstTimeStampInFile(1);
                seizuresListWithTrueDayAssignment(:,2) = 1; %Yes there is a seizure on this line.
                seizuresListWithTrueDayAssignment(:,3:4) = dataSaved_thisArena(:,5:6);
                for(ni = 1:numLines),
                    stringToPrint = sprintf(['%d %d %0.2f %d %0.3f %d' char(10)],dataSaved_thisArena(ni,:));
                    fprintf(thisDay_fID,stringToPrint);
                    %
                    % For the byFly text output, we need to compute the actual
                    % day, rather than the video number.
                end;
                data2save = data2write_byFly{ai};
                if(isempty(data2save)),
                    data2save = seizuresListWithTrueDayAssignment; 
                else
                    data2save = [data2save; seizuresListWithTrueDayAssignment];
                end;
                data2write_byFly{ai,1} = data2save;
            end;
        end;
        fclose(thisDay_fID);
        %--------------------------------------------
    end;
end;


% New table format for Vishnu's statistics collaborators:
% -- Fly ID, Treatment Group, seizure? (binary), Duration of seizure, HK events per seizure
% -- There should be 72 rows in this dataset (18 flies per group x first 4
% days of recording)
% For the file name, use the first fileNamesByDay{1};
maxNumDays = ceil(hoursToAnalyze/24);

for(ai = 1:numArenas),
    thisArenaNum = arenaList(ai);
    if(thisArenaNum==24),
        display('pause here.');
    end;
    %
    % We will need to compute a time of death for this fly:
    thisFlyDat = binnedSleepMat(:,ai);
    [durations,starts,ends] = computeBinaryDurations(thisFlyDat==1);
    deathIndex = find(durations>(sleepDeathCutoff_hrs*2)); %Each bin is 30 minutes, so each hour is 2 bins
    if(~isempty(deathIndex)),
        display('fly death!');
        deathDay = ceil(starts(deathIndex(end))/24);
    else,
        deathDay = maxNumDays;
    end;
    if(deathDay==3),
        display('pause here.');
    end;
    if(ai==1),
        if(~isempty(strfind(fileNamesByDay{di},'Arena 1'))),
            byFlyFileName = strrep(fileNamesByDay{di},'Arena 1-Subject 1.mat',[seizureParamSuffix '_byFly.txt']);
        else,
            byFlyFileName = strrep(fileNamesByDay{di},'-1-Subject 1.mat',[seizureParamSuffix '_byFly.txt']);
        end;
        
        byFly_fID = fopen(byFlyFileName,'w');
        fprintf(byFly_fID,['Arena day #seizures Duration #ofHKevents' char(10)]);
    end;
    
    thisArenaData = data2write_byFly{ai,1};
%     seizureListByDay_thisArena = zeros(maxNumDays,4);
%     seziureListByDay_thisArena(:,1) = thisArenaNum;
    if(~isempty(thisArenaData)),
        ceilingDaysWithSeizure = ceil(thisArenaData(:,1));
        for(di = 1:maxNumDays); %size(fileNamesByDay,1)), %data2write_byDay_byArena,1)),
            % Labels for dataSavedThisArena:
            %             'Hour Min Sec Arena Duration #ofHKevents' char(10)]);
            %                 stringToPrint = sprintf(['%d %d %0.2f %d %0.3f %d' char(10)],dataSaved_thisArena(ni,:));
            thisDayIndices = find(ceilingDaysWithSeizure==di);
            %             seizureListByDay_thisArena(di,2:end) = [di sum(thisArenaData(ceilingDaysWithSeizure,2:end))];
            %             fprintf(byFly_fID,['Arena day #seizures Duration #ofHKevents' char(10)]);
            if(~isempty(thisDayIndices) && numel(thisDayIndices)>0),
                %                 try,
                if(numel(thisDayIndices)==1),
                    stringToPrint = sprintf(['%d %d %d %0.3f %d' char(10)],[thisArenaNum di thisArenaData(thisDayIndices,2:end)]); %dataSaved_thisArena(ni,:));
                else,
                    stringToPrint = sprintf(['%d %d %d %0.3f %d' char(10)],[thisArenaNum di sum(thisArenaData(thisDayIndices,2:end))]); %dataSaved_thisArena(ni,:));
                end;
                %                 catch,
                %                     display('meep.');
                %                 end;
            elseif(di>=deathDay),
                stringToPrint = sprintf(['%d %d %d %d %d' char(10)],[thisArenaNum di -1 -1 -1]); %dataSaved_thisArena(ni,:));
            else,
                stringToPrint = sprintf(['%d %d %d %d %d' char(10)],[thisArenaNum di 0 0 0]); %dataSaved_thisArena(ni,:));
            end;
%             numSpaces =  strfind(stringToPrint,' ');
%             if(numSpaces<4),
%                 display('mrp');
%             end;
            fprintf(thisDay_fID,stringToPrint);
        end;
    else,
        for(di = 1:maxNumDays); %size(fileNamesByDay,1)), %data2write_byDay_byArena,1)),
            if(di>deathDay),
                stringToPrint = sprintf(['%d %d %d %d %d' char(10)],[thisArenaNum di -1 -1 -1]); %dataSaved_thisArena(ni,:));
            else,
                stringToPrint = sprintf(['%d %d %d %d %d' char(10)],[thisArenaNum di 0 0 0]); %dataSaved_thisArena(ni,:));
            end;
%             stringToPrint = sprintf(['%d %d %d %d %d' char(10)],[thisArenaNum di 0 0 0]); %dataSaved_thisArena(ni,:));
            fprintf(thisDay_fID,stringToPrint);
        end;
    end;
end;

%% =====================================================================================
%% function processArena
% Plots we (ie the parent function) want:
% 1) Seizure distribution over 24 hours
% 2) Average # of seizures/day
% 3) Seizure duration - histogram
% 4) Seizure severity (# of events) - histogram
% 5) Seizure duration vs seizure severity scatter plot
% 6) Inter hyperkinetic interval.
%
% Most of these are computed using the parent script - main function of
% processArena is to compute seizures.
%
% Outputs of function processArena:
% seizuresPerDay <= single numerical value per fly.
% seizureOnsetDurationNumHK <= array that for, each seizure, lists the Onset time, the duration number, and the number of hyperkinetic events.
% -- Can be used to generate all the plots listed above except for the inter hyperkinetic interval.
function [seizuresPerDay, seizureOnsetDurationNumHK, interHKeventInterval_hist,hyperKineticEventStartTimes,isSeizure] = processArena(isHyperkinetic,...
    timestamps,numEvents,secondsPerInterval,minBtwnSeizures,interHKeventInterval_bins_sec, xyPositions, distanceThreshold, minEventsPerSeizure)

isSeizure = zeros(size(isHyperkinetic));
if(size(isHyperkinetic,1)>0 && numel(timestamps)>0),
    if(nansum(isHyperkinetic)>0),
        [~,hyperKineticStartIndices,hyperKineticEndIndices] = computeBinaryDurations(isHyperkinetic);
        interHKeventIntervals_sec = (timestamps(hyperKineticStartIndices(2:end),1)-timestamps(hyperKineticEndIndices(1:(end-1),1)))*24*3600;
        [interHKeventInterval_hist,x] = hist(interHKeventIntervals_sec, interHKeventInterval_bins_sec);
        %     hyperKineticDurations_sec = (timeSleepSeizureData(hyperKineticEndIndices,1)-timeSleepSeizureData(hyperKineticStartIndices,1))*24*3600;
        
        hyperKineticEventStartTimes = timestamps(hyperKineticStartIndices,1);
        
        maxNumSeizures = ceil(numel(hyperKineticStartIndices)/numEvents);
        seizureOnsetDurationNumHK = NaN(maxNumSeizures,3);
        seizureOffsetIndicesAndTime = NaN(maxNumSeizures,2);
        %seizureOffsetIndicesAndTime will not be output, but is meant to
        %store the seizure offsets (which is simpler than calculating them
        %de novo or relying on the for loop to keep track).
        
        si=0;
        for(hksi = 1:numel(hyperKineticStartIndices)),
            eventStartTime = hyperKineticEventStartTimes(hksi);
            eventStartIndex = hyperKineticStartIndices(hksi);
            eventEndIndex = hyperKineticEndIndices(hksi);
            eventEndTime = timestamps(eventEndIndex);
            eventDuration = (eventEndTime-eventStartTime);
            
            endTimeToCheck = eventStartTime+1/24/3600*secondsPerInterval; %1/24/2 = 30 min, in units of days
            previousOffset_seizureIndex = find(~isnan(seizureOffsetIndicesAndTime(:,1)),1,'last');
            %             end;
            if(~isempty(previousOffset_seizureIndex) && eventStartIndex<=seizureOffsetIndicesAndTime(previousOffset_seizureIndex,1)),
                %This hksi was already included as part of the previous
                %seizure. Don't need to do any additional computations.
                %                 display(['previous si=' num2str(previousOffset_seizureIndex) ', offset time = ' datestr(seizureOffsetIndicesAndTime(previousOffset_seizureIndex,2))]);
            else,
                %We are outside of the bounds of the previous seizure, but
                %what if we are extending the preceding seizure?
                if(~isnan(previousOffset_seizureIndex)),
                    % Then we need to look at the
                    % previousOffset_seizureIndex and see if this is a
                    % continuation of the previous seiure.
                    
                    timeSincePreviousSeizure_days = eventStartTime-seizureOffsetIndicesAndTime(previousOffset_seizureIndex,2);
                    if(timeSincePreviousSeizure_days<(1/24/60*minBtwnSeizures)),
                        newSeizure = 0;
                    else, %This is a new seizure
                        newSeizure = 1;
                    end;
                else, % there is no previousOffset_seizureIndex (therefore no preceding seizure event).
                    newSeizure = 1;
                end;
                if(newSeizure),
                    subsequentStartTimes = hyperKineticEventStartTimes(hksi:end);
                    numEventsInTime = sum(subsequentStartTimes<endTimeToCheck);
                    %                     display(['hksi = ' num2str(hksi) ', eventStartIndex=' num2str(eventStartIndex) ', numEventsInTime=' num2str(numEventsInTime)]);
                    if(numEventsInTime>=numEvents), % && numEventsInTime>=minEventsPerSeizure),
                        % If we are in this loop, then this is probably a
                        % seizure, but we are now adding a check for
                        % tracking artifacts.
                        lastHKindex = hyperKineticEndIndices(hksi+numEventsInTime-1);
                        
                        [numPointsInside,distFromCentroids]=numPointsInsideXYclusters(xyPositions(eventStartIndex:lastHKindex,:), distanceThreshold);
                        if(numPointsInside<(lastHKindex-eventStartIndex+1)),
                            si = si+1;
                            lastSeizureEndIndex = lastHKindex;
                            isSeizure(eventStartIndex:lastSeizureEndIndex) = 1;
                            seizureOnsetDurationNumHK(si,1) = eventStartTime;
                            seizureDuration = timestamps(lastSeizureEndIndex,1)-eventStartTime;
                            seizureOnsetDurationNumHK(si,2) = seizureDuration;
                            seizureOnsetDurationNumHK(si,3) = numEventsInTime;
                            
                            
                            seizureOffsetIndicesAndTime(si,1) = lastSeizureEndIndex;
                            seizureOffsetIndicesAndTime(si,2) = timestamps(lastSeizureEndIndex);
                            isSeizure(eventStartIndex:eventEndIndex) = 1;
                            display(['Seizure si=' num2str(si) ', duration=' num2str(seizureOnsetDurationNumHK(si,2)*24*3600) ' s, numEvents=' num2str(seizureOnsetDurationNumHK(si,3))]);
                            display(['Start time: ' datestr(seizureOnsetDurationNumHK(si,1)) ', end time: ' datestr(seizureOffsetIndicesAndTime(si,2))]);
                        else,
                            display('bugA!');
                        end;
                    else, %There were an insufficient number of events for this to be considered a seizure.
                        % Two other possibilities:
                        % 1) This is not a seizure
                        % 2) This is a continuation of a preceding seizure.
                        % However, if we have entered this clause it means
                        % that there was no preeding seizure.
                    end;
                else,
                    % We are entering this clause because newSeizure=0.
                    %This COULD be a continuation of the previous seizure, but need to make sure that it fits the definition:
                    %Then this is a continuation of the previous
                    %seizure and we need to reset the following
                    %assuming the minimum number of events per interval
                    %are met.
                    
                    subsequentStartTimes = hyperKineticEventStartTimes(hksi:end);
                    numEventsInTime = sum(subsequentStartTimes<endTimeToCheck);
                    %                     display(['hksi = ' num2str(hksi) ', eventStartIndex=' num2str(eventStartIndex) ', numEventsInTime=' num2str(numEventsInTime)]);
                    if(numEventsInTime>=numEvents),
                        lastHKindex = hyperKineticEndIndices(hksi+numEventsInTime-1);
                        
                        [numPointsInside,distFromCentroids]=numPointsInsideXYclusters(xyPositions(hksi:lastHKindex,:), distanceThreshold);
                        if(numPointsInside<(lastHKindex-hksi+1)),
                            
                            % A) duration and the number of hyperkinetic events
                            % in seizureOnsetDurationNumHK(si,2,3)
                            seizureOnsetDurationNumHK(si,2) = seizureOnsetDurationNumHK(si,2)+timeSincePreviousSeizure_days+eventDuration;
                            seizureOnsetDurationNumHK(si,3) = seizureOnsetDurationNumHK(si,3)+1;
                            % B) Offset indices and time in
                            % seizureOffsetIndicesAndTime.
                            seizureOffsetIndicesAndTime(si,1) = eventEndIndex;
                            seizureOffsetIndicesAndTime(si,2) = eventEndTime;
                            prevSeizureEndIndex = find(isSeizure,1,'last');
                            isSeizure(prevSeizureEndIndex:eventEndIndex) = 1;
                        else,
                            display('bugB!');
                        end;
                    else,
                        %display('bugC!');
                    end;
                end;
            end;
        end;
        trueSeizureIndices = find(~isnan(seizureOnsetDurationNumHK(:,1)) & (seizureOnsetDurationNumHK(:,3)>=minEventsPerSeizure));
        % If trueSeizureIndices is less than the putative number of
        % seizures:
        putativeSeizureIndices = find(~isnan(seizureOnsetDurationNumHK(:,1)));
        falseSeizureIndices = setdiff(putativeSeizureIndices,trueSeizureIndices);
        if(~isempty(falseSeizureIndices))
            for(fsi = 1:numel(falseSeizureIndices))
                thisFalseSeizureIndex = falseSeizureIndices(fsi);
                falseStart = seizureOnsetDurationNumHK(thisFalseSeizureIndex,1);
                falseDuration = seizureOnsetDurationNumHK(thisFalseSeizureIndex,2);
                [~,minStartIndex] = min(abs(timestamps-falseStart));
                [~,minEndIndex] = min(abs(timestamps-(falseStart+falseDuration)));
                isSeizure(minStartIndex:minEndIndex) = 0;
            end;
        end;
        
        seizureOnsetDurationNumHK = seizureOnsetDurationNumHK(trueSeizureIndices,:);
        numSeizures = numel(trueSeizureIndices);
        if(~isnan(timestamps(end))),
            lastNonNanIndex = numel(timestamps);
        else,
            lastNonNanIndex = find(~isnan(timestamps),1,'last');
        end;
        %         end;
        numDays = timestamps(lastNonNanIndex,1)-timestamps(1,1);
        seizuresPerDay = numSeizures/numDays;
        %                 end;
    else, %There are no hyperkinetic movements.
        seizuresPerDay = 0;
        seizureOnsetDurationNumHK = [];
        interHKeventInterval_hist = zeros(size(interHKeventInterval_bins_sec));
        hyperKineticEventStartTimes = [];
    end;
else,
    seizuresPerDay = 0;
    seizureOnsetDurationNumHK = [];
    interHKeventInterval_hist = zeros(size(interHKeventInterval_bins_sec));
    hyperKineticEventStartTimes = [];
end;


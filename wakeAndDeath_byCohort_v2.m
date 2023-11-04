%% function outMat = wakeAndDeath_byCohort(rootdir_line,inputMat_line,arenaNums_line,numEvents,secondsPerInterval,minBtwnSeizures,seizureParamSuffix)
%
% March 12, 2022
% Called by parent function seizure_pwake_pdeath
% Relies on the *.txt outputs of quantifySeizures script.
% Additional metric not in v1: 

function [outMat, headings] = wakeAndDeath_byCohort_v2(rootdir_line,inputMat_line,...
    seizureParamSuffix, secondsBeforeOnsetToCheck, deathCutoff_hrs, precedingMinutesToCheckSleepFraction)
rootdir_line = rootdir_line{1,1};
rootdir = rootdir_line(1:(end-2));
inputMat_line = inputMat_line{1,1};

cd(rootdir_line(1:(end-2)));
matInputNameRoot = inputMat_line(1:(end-2));

display(['About to load ' matInputNameRoot '_sleepData_byTimepoint.mat'])
A = load([matInputNameRoot '_sleepData_byTimepoint.mat']);
% try,
isSleepingMat = A.isSleeping_array2save;
% catch,
display(matInputNameRoot);
% end;
timestampsMat = A.timestamps_array2save;
ZT0_clockHour = A.ZT0_clockHour;
fps = A.fps;
B = load([matInputNameRoot '30minBinnedSleepData.mat']);
% Track-20210914_multiDay_allArenas30minBinnedSleepData
%
% Fields for A:
%             ZT0_clockHour: 10
%           xyToSleepParams: [1x1 struct]
%      firstTimestampInFile: [3x1 double]
%                       fps: 25
%     isSleeping_array2save: [7071236x24 double]
%     timestamps_array2save: [7071236x24 double] %timestamps_array2save has
%     the timestamps saved in datenum units.
%      xPosition_array2save: [7071236x24 double]
%      yPosition_array2save: [7071236x24 double]
%
%   Fields for B:
%         fileNamesByDay: {3x1 cell}
%         binnedSleepMat: [158x24 double]
%         binnedSleep_ZTtime: [158x24 double]
fileNamesByDay = B.fileNamesByDay;
%Check to make sure that isSleepingMat actually has data:
% if(sum(isnan(isSleepingMat(:)))==numel(isSleepingMat(:)))
%     isSleepingMat = sleepOnly_saveSingleCohort(rootdir,fileNamesByDay,ZT0_clockHour);
%     A.isSleeping_array2save = isSleepingMat;
% end;
% save([matInputNameRoot '_sleepData_byTimepoint.mat'],'-struct','A');
% clear A; clear B;

headings = ['arenaNum ZTStartTimeWithDayInfo ZTStartTime Duration(min) #ofHKevents isSleeping_' num2str(secondsBeforeOnsetToCheck)  ...
    's_prior minutesSinceStateChange flyDied lastSeizureBeforeDeath minutesFromOnsetToDeath minutesInPrecedingState fractionOfPrev' ...
    num2str(precedingMinutesToCheckSleepFraction) 'minAsleep'];
seizureDatAllDays = NaN(100*size(fileNamesByDay,1),10);

% First: iterate through each file name and load the seizure data:
indexOffset = 1;
firstDatenumPerFile = NaN(size(fileNamesByDay,1),1);
for(di = 1:size(fileNamesByDay,1)),
    thisDayMatName = fileNamesByDay{di};
    if(~isempty(strfind(thisDayMatName,'-Arena 1-Subject 1.mat'))),
        thisDayFileName = strrep(thisDayMatName,'Arena 1-Subject 1.mat',[seizureParamSuffix '.txt']);
    else,
        thisDayFileName = strrep(fileNamesByDay{di},'-1-Subject 1.mat',[seizureParamSuffix '.txt']);
    end;
    display(['Loading ' thisDayFileName]);
    thisDay_fID =fopen(thisDayFileName);
    try,
    timestampLine = fgets(thisDay_fID); %,['First timestamp: %s %d:%d:%d'])
    catch,
        display('meep');
    end;

    fileStart = split(timestampLine,'First timestamp: ');
    fileStart = fileStart{2,1};
%         catch,
%             display(['Loading ' thisDayFileName]);
    %         thisDay_fID =fopen(thisDayFileName);
    %         timestampLine = fgets(thisDay_fID) %,['First timestamp: %s %d:%d:%d'])
    %
    %         fileStart = split(timestampLine,'First timestamp: ');
    %         fileStart = fileStart{2,1};
    %
%         end;
    fileStart_datenum = datenum(fileStart);
    firstDatenumPerFile(di) = fileStart_datenum;

    headingsToDiscard = fgets(thisDay_fID);
    %     formatString = sprintf(['%d %d %0.2f %d %0.3f %d' char(10)]); %,dataSaved_thisArena(ni,:));
    seizureDataVector = fscanf(thisDay_fID,'%f');
    %     Hour Min Sec Arena Duration #ofHKevents
    numSeizures = numel(seizureDataVector)/6; %original file data scanned in had six columns
    seizureDataMat = reshape(seizureDataVector,6,numSeizures);
    seizureDataMat = seizureDataMat';

    %First we need to convert the timestamp into datenums.
    datenum_seizureOnset=fileStart_datenum+(seizureDataMat(:,1)+seizureDataMat(:,2)/60+seizureDataMat(:,3)/3600)/24;
    endIndex = indexOffset+numSeizures-1;
    if(endIndex>size(seizureDatAllDays,1))
        temp = seizureDatAllDays;
        clear seizureDatAllDays;
        seizureDatAllDays = NaN(endIndex,size(temp,2));
        seizureDatAllDays(1:size(temp,1),1:size(temp,2)) = temp;
        clear temp;
    end;
    seizureDatAllDays(indexOffset:endIndex,1) = datenum_seizureOnset;
    seizureDatAllDays(indexOffset:endIndex,2:4) = seizureDataMat(:,4:6);

    fclose(thisDay_fID);
    indexOffset = indexOffset+numSeizures;
end;

isNumIndices = find(~isnan(seizureDatAllDays(:,1)));
seizureDatAllDays = seizureDatAllDays(isNumIndices,:);
% Want to check for whether it is sleeping one minute in advance; death
% is handled separately in the next loop.
for(si = 1:size(seizureDatAllDays,1)),
    seizureOnset_datenum = seizureDatAllDays(si,1)-secondsBeforeOnsetToCheck/24/3600;
    arenaNum = seizureDatAllDays(si,2);
    %     if(arenaNum,arenaList)
    [~,minI] = min(abs(timestampsMat(:,arenaNum)-seizureOnset_datenum));
    seizureDatAllDays(si,5) = isSleepingMat(minI,arenaNum);
    statePreOnset = isSleepingMat(minI,arenaNum);
    stateChangeIndex = find(isSleepingMat(1:(minI-1),arenaNum)~=statePreOnset,1,'last');
    minutesInState = ((minI-stateChangeIndex+1)/fps+secondsBeforeOnsetToCheck)/60;
    %     try,
    if(isempty(minutesInState))
        seizureDatAllDays(si,6) = NaN; %minutesInState;
    else,
        seizureDatAllDays(si,6) = minutesInState;
    end;

    % Also wanted to check how long it was in state before the state
    % change.
    startOfPreviousState_frames = find(isSleepingMat(1:(stateChangeIndex-1))==statePreOnset,1,'last');
    %display(stateChangeIndex)
    if(isempty(stateChangeIndex)),
        seizureDatAllDays(si,10) = NaN;
    else,
if(isempty(startOfPreviousState_frames)),
seizureDatAllDays(si,10) = NaN;
else,
seizureDatAllDays(si,10) = (stateChangeIndex-startOfPreviousState_frames+1)/fps/60;
end;
    end;

    [~,startIndexForFractionCheck] = min(abs(timestampsMat(:,arenaNum)-precedingMinutesToCheckSleepFraction/60/24));
    isSleeping_fractionToCheck = isSleepingMat(startIndexForFractionCheck:(minI+fps*secondsBeforeOnsetToCheck),arenaNum);
    seizureDatAllDays(si,11) = sum(isSleeping_fractionToCheck)/numel(isSleeping_fractionToCheck);
end;

%To handle death, first want to compute the deathTimes for each array.
arenasWithSeizures = unique(seizureDatAllDays(:,2));
% seizureLinesForGroup = [];
for(ai = 1:numel(arenasWithSeizures))
    arenaNum = arenasWithSeizures(ai);
        thisArenaSeizureIndices = find(seizureDatAllDays(:,2)==arenaNum);
        lastWakeIndex = find(isSleepingMat(:,arenaNum)==0,1,'last');
        if(lastWakeIndex==size(isSleepingMat,1)),
            seizureDatAllDays(thisArenaSeizureIndices,7)=0;
        else,
            lastSleepDuration_hrs = (size(isSleepingMat,1)-lastWakeIndex)/fps/3600;
            if(lastSleepDuration_hrs>=deathCutoff_hrs)
                seizureDatAllDays(thisArenaSeizureIndices,7)=1;
                % Need to compute:
                % 1) If this is the last seizure (largest datenum)
                thisArenaSeizureOnset_datenums = seizureDatAllDays(thisArenaSeizureIndices,1);
                [~,maxI] = max(thisArenaSeizureOnset_datenums);
                seizureDatAllDays(thisArenaSeizureIndices,8) = 0;
                seizureDatAllDays(thisArenaSeizureIndices(maxI),8) = 1;
                % 2) Time until death
                timeUntilDeath = timestampsMat(lastWakeIndex,arenaNum)-thisArenaSeizureOnset_datenums;
                seizureDatAllDays(thisArenaSeizureIndices,9) = timeUntilDeath*24*60;
            else,
                seizureDatAllDays(thisArenaSeizureIndices,7)=0;
            end;
        end;
%     end;
end;

%outmat is identical to seizureDatAllDays except for a few differences:
%1) Arena numbers are no longer needed.
outMat = NaN(size(seizureDatAllDays,1),size(seizureDatAllDays,2)+1);
% outMat(:,1) = seizureDatAllDays(:,1);
outMat(:,4:end) = seizureDatAllDays(:,3:end);

%2) Also want to reconvert the timestamps into ZT time.
firstDatevecInCohort = datevec(min(firstDatenumPerFile));
firstDatevecInCohort(4) = ZT0_clockHour;
firstDatevecInCohort(5:end)=0;
outMat(:,1) = seizureDatAllDays(:,2);
outMat(:,2) = (seizureDatAllDays(:,1)-datenum(firstDatevecInCohort))*24;
outMat(:,3) = mod(outMat(:,2),24); %seizureDatAllDays(:,1)-datenum(firstDatevecInCohort);
outMat(:,4) = outMat(:,4)/60;
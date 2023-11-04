%% function sleepFromSingleWell_simple(varargin)
%
% July 18, 2021
%
% Modified from "sleepFromSingleWell.m" for Vishnu's new format of
% Ethovision exported data, which has far fewer parameters:
% "Trial time";"Recording time";"X center";"Y
% center";"Area";"Areachange";"Elongation";"Multi condition";"Result 1";
%
% Expects readSingleWellData to be run in order to generate a *.mat file
% that this script can read.
%
% To do (February 10, 2021) - copied over from sleepFromSingleWell.m
% 1) Export 30 min bins - maybe let user set bin size?
% 2) Have user input the first time to read?isSleepingIndices,
% 3) Translate into ZT values
%
% Outputs a matrix containing the following:
% 1) datenum
% 2) isSleeping
% 3) multiCondition: is seizing



function [outputMat, xyToSleepParams,fps] = sleepFromSingleWell_simple(varargin)
% close all;
%According to Abby's instructions on the server, you can export the file in
%EthoVision with the following:
% "Under “dependent variables list” (the one to the left of the white list), click the box next to “movement”. A box will pop
%     up. Under “threshold”, put start velocity as 0.125 (might round up to 0.13) and stop velocity as 0.05. SCREENSHOT .
%     Under the “statistics” menu in the same window, select “frequency” and “cumulative direction”. Everything else should
%     be unchecked"
% Currently (Feb 10, 2021, analyzing data generated 1/22/2021): ignore the "Movement" binary in the text file because it
% was generated with the wrong calibration. However, may be useable
% someday.
readMovementFromFile = 0;
conversionFactor = 10; %Should usually be 10 (1 cm = 10 mm)
%conversionFactor = 1.56/2*10; % Assuming an accurate calibation, this can
%be set to 10 (as above), but otherwise can also use it to convert in the
%event of inaccurate calibration.

stopVelocity_mm_per_s = 0.5; %From Garbe et al (2015) for female fly, termination of movement threshold for 50% of body length.
startVelocity_mm_per_s = 1.2; %From Garbe et al (2015) for female fly, movement threshold for 50% of body length.
minutesOfSleep_definition = 5;
debugMode = 0; %If set to 1, will plot velocity. Turned off to facilitate compiling of batch data.

xyToSleepParams.conversionFactor = conversionFactor;
xyToSleepParams.stopVelocity_mm_per_s = stopVelocity_mm_per_s; %From Garbe et al (2015) for female fly, termination of movement threshold for 50% of body length.
xyToSleepParams.startVelocity_mm_per_s = startVelocity_mm_per_s; %From Garbe et al (2015) for female fly, movement threshold for 50% of body length.
xyToSleepParams.minutesOfSleep_definition = 5;
debugMode = 0; %If set to 1, will plot velocity. Turned off to facilitate compiling of batch data.

if(nargin==0),
    rootdir = 'C:\Users\Windows 10\Dropbox\Sehgal Lab\Seizures\EthoVision\210323';
    %    rootdir = 'C:\Users\Windows 10\Dropbox\Sehgal Lab\Seizures\EthoVision\tko caffeine seizure test';
    filename = 'Track-20210323 iso and tko in veh, caf, picro-Trial     1-Arena 12-Subject 1.mat';
    fps = 30;
    firstTimeToRead = '01/22/2021 15:18:08'
    % firstTimeToRead = '01/22/2021 15:18:08' %Example date/time
    % NOTE: Matlab can not handle partial seconds, although these are exported by EthoVision - please do not enter partial seconds as the firstTimeToRead.
    
    cd(rootdir);
else,
    filename = varargin{1};
%     fps = varargin{2};
%     eventsPer30min_threshold;
end;

tic;
A = load(filename);

startDate_string = A.startDate;
colonIndices = strfind(startDate_string,':');
%        numHrs = str2num(durationString(1:(colonIndices(1)-1)));
durationDateString = startDate_string(1:(colonIndices(end)+2));
durationVec = datevec(durationDateString,'mm/dd/yyyy HH:MM:SS');
startDate_datenum = datenum(durationVec); %startDate_string); %datenum is in units of days.
fps = round(1/nanmean(diff(A.outputMat(:,1))));
xyData = A.outputMat(:,3:4);
isNumIndices = find(~isnan(xyData(:,1)));
interpX = interp1(isNumIndices,xyData(isNumIndices,1),1:size(xyData,1));
interpY = interp1(isNumIndices,xyData(isNumIndices,2),1:size(xyData,1));
interpXY = [interpX(:) interpY(:)]*conversionFactor;

outputMat = NaN(size(interpXY,1),6);
% outputMat has 6 columns: date, x, y, isSleeping, isSeizing, isMoving
outputMat(:,1) = A.outputMat(:,1)/24/3600+startDate_datenum;
outputMat(:,2:3) = interpXY;
% display(A.columnTitles_line)

%% Vishnu's "Multi-condition" column indicates his manually set thereshold for hyperkinetic movements.
% We use the eventsPer30min_threshold variable, also manually set by
% Vishnu, to distinguish remove false positives (hyperkinetic movements
% that are not seizures).

multiConditionColumnTextIndex = strfind(A.columnTitles_line,'Multi');
multiConditionColumnIndex = ceil(numel(strfind(A.columnTitles_line(1:multiConditionColumnTextIndex(1)),'"'))/2);
outputMat(:,5) = A.outputMat(:,multiConditionColumnIndex); 
%If we didn't want to filter out MultiCondition events for false positives
%using the "eventsPer30min_threshold", we would use the above line.
%
% On second thought, maybe converting hyperkinetic movements to seizures is
% better done in the parent function, consolidateMultiDayArenaData, so that
% we can examine 30 min bins across multiple recordings.
% isHyperkinetic = A.outputMat(:,multiConditionColumnIndex); 
% [hyperKineticDurations,hyperKineticStartIndices,hyperKineticEndIndices] = computeBinaryDurations(isHyperkinetic);
% 
% for(hksi = 1:numel(hyperKineticStartIndices)),
% end;



%% Here: computing velocity in order to determine when flies are moving or not (later used to compute whether or not the fly is sleeping).
% NEED TO SUBSAMPLE X AND Y FOR COMPUTING "isMoving" above threshold
% values.
velocity_interpFromXY =sqrt(((diff(interpX)).^2)+((diff(interpY)).^2));
% velocity(isNanIndices_velocity) = velocity_interpFromXY(isNanIndices_velocity-1);
% velocity_mm_per_frame = velocity_interpFromXY*conversionFactor;

if(readMovementFromFile),
    isMovingColumnTextIndices = strfind(A.columnTitles_line,'Movement');
    isMovingColumnNum = ceil(numel(strfind(A.columnTitles_line(1:isMovingColumnTextIndices(1)),'"'))/2);
    isMoving_vectorFromFile = A.outputMat(:,isMovingColumnNum);
end;
% 
% %Velocity is currently in terms of cm/frame.
% velocity_mm_per_s = velocity*conversionFactor*fps; %10;
% %INSTEAD OF CONVERTING THIS, NEED TO SUBSAMPLE BY SECOND.
xy_subsample = interpXY(1:fps:end,:);
velocity_mm_per_s_subsample = sqrt(((diff(xy_subsample(:,1)).^2)+((diff(xy_subsample(:,2))).^2)));
velocity_mm_per_s_interpOverFrames = interp1(1:fps:(numel(velocity_mm_per_s_subsample)*fps),velocity_mm_per_s_subsample,1:(numel(velocity_mm_per_s_subsample)*fps)); %1:numel(velocity_interpFromXY)); 
offset = floor((numel(velocity_interpFromXY)-numel(velocity_mm_per_s_interpOverFrames))/2);
velocity_mm_per_s(offset:(offset+numel(velocity_mm_per_s_interpOverFrames)-1)) = velocity_mm_per_s_interpOverFrames;

if(debugMode)
figure(1);
plot(velocity_mm_per_s);
ylabel('Velocity (mm/s)');
end;

% inactivityIndices = find(velocity_mm_per_s<noMovementThreshold_mm_per_s);
%
% isMoving = ones(size(velocity_mm_per_s));
% isMoving(inactivityIndices) = 0;
% % area(isWake);
% notMoving = velocity_mm_per_s<noMovementThreshold_mm_per_s;
%
if(~readMovementFromFile),
    [~, movementStartIndices, ~] = computeBinaryDurations(velocity_mm_per_s>=startVelocity_mm_per_s);
    [~, terminationStartIndices, ~] = computeBinaryDurations(velocity_mm_per_s<stopVelocity_mm_per_s);
    % startStopIndices = NaN(numel(movementStartIndices),2);
    isMoving = zeros(size(velocity_mm_per_s));
    for(msi = 1:numel(movementStartIndices)),
        thisMovementStartIndex = movementStartIndices(msi);
        terminationStartSubindex = find(terminationStartIndices>thisMovementStartIndex,1);
        thisMovementEndIndex = terminationStartIndices(terminationStartSubindex)-1;
        isMoving(thisMovementStartIndex:thisMovementEndIndex) = 1;
    end;
    toc
end;
if(readMovementFromFile)
    isMoving = isMoving_vectorFromFile;
    isNanIndices = find(isnan(isMoving));
    isMoving(isNanIndices) = 0;
end;
outputMat(1:numel(isMoving),6) = isMoving;

[inactivityDurations,inactivityStartIndices,inactivityEndIndices] = computeBinaryDurations(isMoving==0); %|isnan(isMoving)); %velocity_mm_per_s>=startVelocity_mm_per_s);
sleepBoutIndices = find(inactivityDurations>=(minutesOfSleep_definition*60*fps));
noMovementWakeIndices = find(inactivityDurations<(minutesOfSleep_definition*60*fps));

isSleeping = zeros(size(isMoving));
for(si = 1:numel(sleepBoutIndices)),
    sleepStart = inactivityStartIndices(sleepBoutIndices(si));
    sleepEnd = inactivityEndIndices(sleepBoutIndices(si));
    isSleeping(sleepStart:sleepEnd) = 1;
end;

% display(size(isSleeping));
% display(size(outputMat));
outputMat(1:numel(isSleeping),4) = isSleeping;

%isSleeping binary array above is in units of frames.
floor_numMinutesOfData = floor(numel(isSleeping)/(60*fps));
isSleeping_truncated = isSleeping(1:(floor_numMinutesOfData*60*fps));
isSleepingBinary_reshapedByMin = reshape(isSleeping_truncated,60*fps,floor_numMinutesOfData);
isSleepingBinary_min = sum(isSleepingBinary_reshapedByMin,1)/60/fps;
if(debugMode)
figure(2);
area(1:numel(isSleepingBinary_min),isSleepingBinary_min);
end;
display(['Minutes of sleep = ' num2str(sum(isSleepingBinary_min))]);
if(numel(isSleepingBinary_min)>=1440),
display(['Minutes of sleep in first 24 hours = ' num2str(sum(isSleepingBinary_min(1:1440)))]);
else,
    display(['Only ' num2str(numel(isSleepingBinary_min)) ' minutes of data recorded.']);
end;
display(['Sum of Movement column from file (divided by minutes) = ' num2str(nansum(isMoving)/fps/60)]);

%%
% Is it possible that seizure are being mistakenly classified as sleep?
% With the exception of velocity, probably want to classify all parameters
% both in terms of "While awake" versus "While asleep"?
% -- 1) While moving
% -- 2) While not moving awake
% -- 3) While sleeping.

% Parameter list:
% "Trial time";"Recording time";"X center";"Y center";
% "Area";"Areachange";"Elongation";
% "Movement(Moving / center-point)";"Movement(Not Moving / center-point)";
% --- For the most part, Movement has already been incorporated into the
% sleep metric, but duration of movement is still a
% "Acceleration";"Acceleration state(center-point / High acceleration)";"Acceleration state(center-point / Low acceleration)";
% --- Want to take first "Acceleration" column number. Don't need to
% compute this for the sleeping fly.
% "Velocity";
% "Mobility";"Mobility state(Highly mobile)";"Mobility state(Mobile)";"Mobility state(Immobile)";"Very Fast Movement(Moving / center-point)";"Very Fast Movement(Not Moving / center-point)";"Result 1";
% --- Want to take first "Mobility" column number.
% 
% isMovingIndices = find(isMoving==1);
% velocityDuringMovement = velocity_mm_per_s(isMovingIndices);
% % sleepBoutIndices = find(inactivityDurations>=(minutesOfSleep_definition*60*fps));
% % noMovementWakeIndices = find(inactivityDurations<(minutesOfSleep_definition*60*fps));
% sleepBoutDurations = inactivityDurations(sleepBoutIndices);
% quietWakeDurations = inactivityDurations(noMovementWakeIndices);
% [movementDurations,~,~] = computeBinaryDurations(isMoving);

toc

%%
function outputColumn = getColumnGivenString(inputMat,columnTitles,string2match)
velocityColumnTextIndex = strfind(columnTitles,string2match);
% velocityColumnTextIndex = strfind(A.columnTitles_line,'Velocity');
% %But: I'm going to assume (by manually looking at the text file) that
% %velocity is output in terms of cm/s).
velocityColumnNum = ceil(numel(strfind(columnTitles(1:velocityColumnTextIndex(1)),'"'))/2);
outputColumn = inputMat(:,velocityColumnNum);
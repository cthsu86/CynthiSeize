%% function seizure_pwake_pdeath()
% March 10, 2022
%
% Assumes quantifySeizures_multiCondition_multiCohort_v13 has been run
% previously:
% 1) Reads in the list of seizure statistics, and adds two columns: Is fly awake? Will fly die?
%
% Is this the last seizure before the fly dies? If so, how many seconds
% following seizure offset is the fly dead?
function seizure_pwake_pdeath()
close all;

primedir = 'G:\My Drive\Sehgal Lab\Data analysis\Video Tracking\2021.08 Cynthia Hsu scripts'; %Example Analysis';
filename = 'pdf, pdfGtACR_Sept2023_ZT10-14_0.25.txt';

secondsBeforeSeizureOnset_checkWake = 60;
% Currently checking at time indicated. If this variable doesn't exist, or
% a range of times (such as [-300 0]) exists instead,
% outputs P_wake, which integrates over the time range indicated, rather than isWake (binary)
% This is a PLANNED function, not an already implemented function, so don't
% try entering in a range for this variable (Jan 11, 2022).
precedingMinutesToCheckSleepFraction = 180;

deathCutoff_hrs = 15;
maxNumCohorts = 100; %Should be greater than the number of cohorts listed in the input file.

%quantifySeizures_multiCondition_multiCohort_v9 calls processCohort_v6,
%which for every cohort saves the following:
% if(outputSeizureListsPerVideo),
%     for(di = 1:size(data2write_byDay_byArena,1)),
%         thisDayFileName = strrep(fileNamesByDay{di},'Arena 1-Subject 1.mat',[seizureParamSuffix '.txt']);
%         thisDay_fID =fopen(thisDayFileName,'w');
%         fprintf(thisDay_fID,['First timestamp: ' datestr(firstTimeStampInFile(di)) char(10) ...
%             'Hour Min Sec Arena Duration #ofHKevents' char(10)]);
%         for(ai = 1:numArenas),
%             dataSaved_thisArena = data2write_byDay_byArena{di,ai};
%             numLines = size(dataSaved_thisArena,1);
%             for(ni = 1:numLines),
%                 stringToPrint = sprintf(['%d %d %0.2f %d %0.3f %d' char(10)],dataSaved_thisArena(ni,:));
%                 fprintf(thisDay_fID,stringToPrint);
%             end;
%         end;
%         fclose(thisDay_fID);
%     end;
% end;


tic;
cd(primedir);
fID = fopen(filename);

numEventsPerTimePeriod_text = fgets(fID);
a = sscanf(numEventsPerTimePeriod_text,'%d hyperkinetic events per %d seconds');
numEvents = a(1);
secondsPerInterval = a(2);

btwnSeizure_text = fgets(fID);
minEventsPerSeizure = sscanf(btwnSeizure_text,'At least %d events per seizures');

btwnSeizure_text = fgets(fID);
minBtwnSeizures = sscanf(btwnSeizure_text,'%d minutes between seizures');

% Read in #hk events per time period in first line.
% minutes between seizures in second line.
suffix = ['_' num2str(numEvents) 'hkEvents_per_' num2str(secondsPerInterval) 's_' ...
    num2str(minBtwnSeizures) 'min_btwnSeizures_atLeast' num2str(minEventsPerSeizure) 'events_processCohort_v17'];
% Track-20210914 CS control and picro-Trial     1-_5hkEvents_per_50s_60min_btwnSeizures_atLeast7events_processCohort_v9_CS+picro

outputName = strrep(filename,'.txt',[suffix '_seizures_pwake_pdeath.txt']);

% Third line tells you how many groups we are reading in:
% '2 groups'
numGroupText = fgets(fID);
numGroups = sscanf(numGroupText,'%d group');

% Subsequent lines contain information about each of the groups (as indicated by "numGroups" that we are reading information for.
groupLabel = cell(numGroups,1);
for(gi = 1:numGroups),
    groupColorText = fgets(fID);
%     display(groupColorText);
%     display(numGroups);
    [a,~,~,nextIndex] = sscanf(groupColorText,'G%d: %f %f %f');
%     groupColors(gi,:) = a(2:4);
    thisLabel = groupColorText((nextIndex+1):end); %Assumes there is a space between the color and the group label
    % Checks for a newline at the end of the line
    try,
        newLineCharIndex = strfind(thisLabel,13);
    catch,
        newLineCharIndex = find(thisLabel==13);
    end;
    if(~isempty(newLineCharIndex)),
        thisLabel = thisLabel(1:(newLineCharIndex-1));
    end;
    groupLabel{gi,1} = thisLabel;
end;

cohortData = cell(maxNumCohorts,2+numGroups);
cohortIndex = 0;
while(~feof(fID)),
    nextLine = fgets(fID);
    if(~isempty(strfind(nextLine,'rootdir:'))),
        cohortIndex = cohortIndex+1;
        rootdir_line = nextLine(10:end);
        inputMat_line = fgets(fID);
        cohortData{cohortIndex,1} = rootdir_line;
        cohortData{cohortIndex,2} = inputMat_line;
        for(gi = 1:numGroups),
            arenaNums_textLine = fgets(fID); %cell(numGroups,1);
            cohortData{cohortIndex,2+gi} = arenaNums_textLine; %fgets(fID);
        end;
    end; %Now closing all processing associated with 'rootdir'
end;
fclose(fID);


cd(primedir);
fOutID = fopen(outputName,'w');
%   This will be where we put the "by seizure" data.
%     display(['Currently reading group ' groupLabel{gi}]);
for(ci = 1:cohortIndex), %(cohortIndex-1)),
    for(gi = 1:numGroups),
        [thisCohortSeizureDat,headings] = wakeAndDeath_byCohort_v2(cohortData(ci,1),cohortData(ci,2),... %rootdir,filename
            [suffix '_' groupLabel{gi}], ...
            secondsBeforeSeizureOnset_checkWake,deathCutoff_hrs, precedingMinutesToCheckSleepFraction);%These are used to generate the filename of the seizure timestamps.
        % Original *_seizures.txt headings: GroupName ZTStartTimeWithDayInfo ZTStartTime Duration(min) #hk
        % New headings: ['GroupName ZTStartTimeWithDayInfo ZTStartTime Duration #ofHKevents isSleeping minutesSinceStateChange flyDied lastSeizureBeforeDeath minutesFromOnsetToDeath'];
        cd(primedir)
        if(ci==1 && gi==1),
            fprintf(fOutID,['GroupName ' headings char(10)]);
        end;
        for(si = 1:size(thisCohortSeizureDat)),
            thisSeizureText = sprintf('%f ',thisCohortSeizureDat(si,:));
            lineToPrint = [groupLabel{gi} ' ' thisSeizureText char(10)];
            fprintf(fOutID,lineToPrint);
            clear lineToPrint;
            clear thisSeizureText;
        end;
        clear thisCohortSeizureDat;
    end;
end;

fclose(fOutID);

toc;
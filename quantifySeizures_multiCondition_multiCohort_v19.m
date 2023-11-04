%% function quantifySeizures_multiCondition_multiCohort_v19()
% 
% v19: October 28, 2023
% Bug fix to be able to handle experiments less than 24 hours long.
%
% v18: December 16, 2022
% Algorithmically should be identical to v17, but with the added
% functionality of outputting data in a format that can be utilized by
% Vishnu's statistics collaborators:
% -- Fly ID, Treatment Group, seizure? (binary), Duration of seizure, HK events per seizure
% -- There should be 72 rows in this dataset (18 flies per group x first 4 days of recording)
%
% v17: Can specify how many days to analyze (assumes you are starting at
% the beginning).
% v16: Vishnu observed that the number of seizures reported for the 30 min
% bins were less than the number of bins reported for the 24 hrs/day, so
% the goal of this version is to correct for that.
% v15: correcting a ZT times bug that was sometimes choking up the program.
% v14: thetaLabels and direction corrected. Also removed compass plots
% since polar plots are our preferred representation.
% v13: Interfaces with processCohort_v8. Based on v10, but with edits to account for proper axes scaling.
% Also interfaces with an updated version of processCohort_v7 that includes the extra qualifier for number of seizures.
%
% v10: timestamp of seizures with respect to the whole experiment (rather than with respect to the video) was not being saved.
%
% v9: Two additional modifications requested:
% 1) In addition to discarding partial bin sleep data, partial bin seizure
% data is also discarded.
% 2) Seizure Onset Time output in the *_seizures.txt file. (This has been
% done - noted 3/18/2022)
%
% v8: Because Vishnu requested info about partial day sleep, I got nervous
% and wanted to make sure I didn't mess up v7 during the implementation.
%
% v7, unlike v6, uses processCohort_v5 instead of processCohort_v4
% This enables outputs in terms of minutes of seizures rather than number
% of individual seizure events.
%
% Assumes user has previously run sleepAndSeizure_saveSingleCohort_separateMats_v2.m
% Loads *_hyperkineticData_byTimepoint.mat, which ONLY contains a hyperkinetic binary.
% Also loads timestamps.
%
% For the single cohort, shows the following:
% 1) Seizure distribution over 24 hours
% 2) Average # of seizures/day
% 3) Seizure duration - histogram
% 4) Seizure severity (# of events) - histogram
% 5) Seizure duration vs seizure severity scatter plot
% 6) Time since previous hyperkinetic event.
%
%% Modifications from quantifySeizures_singleCondition_multiCohort_v2():
% - Also outputs a list of seizure times for each arena, with a single
% list (txt file) per cohort.
% --- Final plotting script will use the same
% input file to determine locations of this list for all cohorts and read
% in the corresponding sleep data for examining states before seizures.
% - Can plot 2 cohorts in 2 different colors.

%% Sample input text file:
% 5 hyperkinetic events per 300 seconds
% 15 minutes between seizures
% 2 groups
% G1: 1 0 0 eas caffeine
% G2: 0 0 0 eas ctrl
%
% rootdir: C:\Users\Windows 10\Dropbox\Sehgal Lab\Seizures\EthoVision\July 2021 Summary Data
% Track-20210622_multiDay_allArenas
% 6 12 18 24
% 5 11 17 23
%
% rootdir: C:\Users\Windows 10\Dropbox\Sehgal Lab\Seizures\EthoVision\July 2021 Summary Data
% Track-20210616_multiDay_allArenas
% 6 12 18 24
% 5 11 17 23
function quantifySeizures_multiCondition_multiCohort_v17()
versionNum = 17; % Used in naming the output file.
close all;
try
    pkg load statistics
catch,
end;
primedir = 'G:\My Drive\Sehgal Lab\Data analysis\Video Tracking\2021.08 Cynthia Hsu scripts'; %Example Analysis';
filename = 'MB122B, MB122BcsChrimson_Oct2023_ATC.txt';

hoursToAnalyze = 96;

maxNumFlies = 100; %Should be larger than the expected number of flies listed in the filename.
maxNumCohorts = 10; %Should be larger than the expected number of experimental cohorts listed in the filename.

% These parameters are passed into the 'processCohort' subroutine.
outputSeizureListPerVideo = 1; %If set to 1, will output a separate text file for every video containing timestamps of the seizures.
%Set to 0 to improve runtime.

%These parameters affect plotting (also passed into processCohort subroutine to simplify its outputs).
sleepDeathCutoff_hrs = 15;
seizureDurationHistogram_bins_sec = [0:1800:7200]; %[0:15:(60*60)];
hkPerSeizure_bins = [0:10:100];
seizure_hkPerMin_histogramBins = [0.05:0.05:4]; %0.05 = 1/20 of a minute (3 seconds)
%5) time between hkevents
interHKeventInterval_bins_sec = [0:5:600];
interseizureInterval_bins_hrs = [0:1:36];
%6) Doesn't need specific plotting bins (XY scatterplot)
% User does not need to change anything below this line.
%% ========================================================
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
    num2str(minBtwnSeizures) 'min_btwnSeizures_atLeast' num2str(minEventsPerSeizure) 'events_processCohort_v' num2str(versionNum)]
outputName = strrep(filename,'.txt',suffix);

% Third line tells you how many groups we are reading in:
% '2 groups'
numGroupText = fgets(fID);
numGroups = sscanf(numGroupText,'%d group');

% Subsequent lines contain information about each of the groups (as indicated by "numGroups" that we are reading information for.
groupColors = NaN(numGroups,3);
groupLabel = cell(numGroups,1);
for(gi = 1:numGroups),
    groupColorText = fgets(fID);
    [a,~,~,nextIndex] = sscanf(groupColorText,'G%d: %f %f %f');
    groupColors(gi,:) = a(2:4);
    thisLabel = groupColorText((nextIndex+1):end); %Assumes there is a space between the color and the group label
    % Checks for a newline at the end of the line
    try,
        newLineCharIndex = strfind(thisLabel,13);
    catch,
        newLineCharIndex = find(thisLabel==13);
        %    display('Not a string bug.')
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
    %     display(nextLine);
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
        %         cohortIndex = cohortIndex+1;
    end; %Now closing all processing associated with 'rootdir'
end;


% Because we are now handling more than one group, we need to
% change how processCohort and the subsequent plotting lines output
% and use the data.
%
% Alternately, we could do the computationally inefficient thing
% and just reload the matrices "numGroups" times?
% Actually, no we can't - will need to be able to distingiuish
% between each group. But saving the parameters from the text read through
% and then having a separate "Load and analyze" section makes this
% possible.

%[suffix '_' groupLabel{gi}];
outputName_seizureDat = strrep(outputName,suffix,[suffix '_seizures.txt']);
fID_seizures = fopen(outputName_seizureDat,'w');
fprintf(fID_seizures,['GroupName ZTStartTimeWithDayInfo ZTStartTime Duration(min) #hk' char(10)]);

for(gi = 1:numGroups),
    %   This will be where we put the "by seizure" data.
    
    seizuresPerDay_allFlies = NaN(maxNumFlies,1);
    sleepPerDay_flyVsSleepType = NaN(maxNumFlies,3);
%     seizuresPerDay_allFlies_withGroupFlyNum = NaN(size(seizuresPerDay_allFlies,1),size(seizuresPerDay_allFlies,2)+2); %maxNumFlies,3);
    timestampsStartEnd_offsetByDay = NaN(maxNumFlies,3);
    nextFlyIndex = 1;
    for(ci = 1:cohortIndex), %(cohortIndex-1)),
        arenaListText = cohortData(ci,2+gi);
        if(1), %arenaListIsEmpty~=1),
        %--- Start of dumb giant output list for processCohort function----
        [seizureMat,seizuresPerDay, seizureDurationHist,hkPerSeizureHist,hkPerMinHist, interHKeventInterval_singleCohortHist, ...
            interseizureInterval_singleCohortHist, binnedSleep_ZTtime_singleCohort, binnedSleepMat_singleCohort, binnedSeizureMat_singleCohort, ...
            binnedHkEvent_singleCohort, binnedSeizureMinutes_singleCohort,timestampsStartEnd_offsetByDay_singleCohort]...
            ... %Outputs of processCohort_v7 above.
            ... % Below: Values read in from the user input filename:
            ... % Row 1: rootdir
            ... % Row 2: TrackName
            ... % Row 2+gi: arenaList
            =processCohort_v13(cohortData(ci,1),cohortData(ci,2),arenaListText,numEvents,secondsPerInterval,minBtwnSeizures,...
            seizureDurationHistogram_bins_sec,hkPerSeizure_bins,seizure_hkPerMin_histogramBins,...
            interHKeventInterval_bins_sec, interseizureInterval_bins_hrs,[suffix '_' groupLabel{gi}],outputSeizureListPerVideo,...
            minEventsPerSeizure, hoursToAnalyze,sleepDeathCutoff_hrs);
%         %containsSeizureInB
%         if(~isempty(find(sum(binnedSeizureMat_singleCohort)>0)>0))
%             % binnedSeizureMat_singleCohort repeatedy returns zero, even in cases where there is a
%             % seizure - is it used to compute anything?
%             % Yes - binnedSeizures_allCohorts
%             display('seizure found');
%         end;
        %--- End of dumb giant input list for processCohort function----
        seizuresPerDay_allFlies(nextFlyIndex:(nextFlyIndex+numel(seizuresPerDay)-1)) = seizuresPerDay;
%         seizuresPerDay_allFlies_withGroupFlyNum(nextFlyIndex:(nextFlyIndex+numel(seizuresPerDay-1),3:end) = seizuresPerDay;
        timestampsStartEnd_offsetByDay(nextFlyIndex:(nextFlyIndex+size(timestampsStartEnd_offsetByDay_singleCohort,1)-1),:) = timestampsStartEnd_offsetByDay_singleCohort;
        
        % The code "sleepAndSeizure_saveSingleCohort_separateMats_v2.m
        % preallocates a matrix that is # of bins by # of arenas, where the
        % maximum possible arena number is 24.
        fliesInCohort = size(binnedSleep_ZTtime_singleCohort,2);
        if(ci>1), %exist('seizureDurationHist_allCohorts','var')),
            seizureDurationHist_allCohorts = seizureDurationHist_allCohorts+seizureDurationHist; %ogram_bins_sec;
            hkPerSeizureHist_allCohorts = hkPerSeizureHist_allCohorts+hkPerSeizureHist;
            hkPerMinHist_allCohorts = hkPerMinHist_allCohorts+hkPerMinHist;
            interHKeventInterval_allCohorts = interHKeventInterval_allCohorts+interHKeventInterval_singleCohortHist;
            interseizureInterval_allCohorts = interseizureInterval_allCohorts + interseizureInterval_singleCohortHist;
            f = figure(1); %,'PaperPosition',[100 100 1200 900],'PaperUnits','Points');
            h = f;
            set(h,'Units','Pixel','Position',[100 100 1200 900]); %f.Position); %,'PaperUnits','Pixel','PaperPosition',[100 100 1200 600]);
        else,
            % Everything needs to be initialized.
            seizureDurationHist_allCohorts = seizureDurationHist;
            hkPerSeizureHist_allCohorts = hkPerSeizureHist;
            hkPerMinHist_allCohorts = hkPerMinHist;
            interHKeventInterval_allCohorts = interHKeventInterval_singleCohortHist;
            interseizureInterval_allCohorts = interseizureInterval_singleCohortHist;
            % The following matrices are initialized to NaNs because the assignment happens later
            % regardless of whether or not the matrix has been initialized.
            binnedSleep_ZTtime_allCohorts = NaN(size(binnedSleep_ZTtime_singleCohort,1),maxNumFlies);
            binnedSleep_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts));
            binnedSeizures_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts));
            binnedHkEvents_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts));
            binnedSeizureMinutes_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts)); %binnedSeizureMinutes_singleCohort;
        end;
        lastFlyIndexInCohort = nextFlyIndex+fliesInCohort-1;
        if(lastFlyIndexInCohort>size(binnedSleep_ZTtime_allCohorts,2) || size(binnedSleep_ZTtime_singleCohort,1)>size(binnedSleep_ZTtime_allCohorts,1)),
            temp = binnedSleep_ZTtime_allCohorts;
            clear binnedSleep_ZTtime_allCohorts;
            binnedSleep_ZTtime_allCohorts = NaN(max(size(binnedSleep_ZTtime_singleCohort,1),size(temp,1)),...
                max(size(binnedSleep_ZTtime_singleCohort,2),size(temp,2)));
            %binnedSleep_ZTtime_allCohorts has two dimensions, with size set to whether temp or the new one is bigger.
            binnedSleep_ZTtime_allCohorts(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = binnedSleep_allCohorts;
            clear binnedSleep_allCohorts;
            binnedSleep_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts));
            binnedSleep_allCohorts(1:size(temp,1),1:size(temp,2)) = temp;
            temp = binnedSeizures_allCohorts;
            clear binnedSeizures_allCohorts;
            binnedSeizures_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts));
            binnedSeizures_allCohorts(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = binnedHkEvents_allCohorts;
            clear binnedHkEvents_allCohorts;
            binnedHkEvents_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts));
            binnedHkEvents_allCohorts(1:size(temp,1),1:size(temp,2)) = temp;
            temp = binnedSeizureMinutes_allCohorts;
            clear binnedSeizureMinutes_allCohorts;
            binnedSeizureMinutes_allCohorts = NaN(size(binnedSleep_ZTtime_allCohorts));
            binnedSeizureMinutes_allCohorts(1:size(temp,1),1:size(temp,2)) = temp;
            
        end;
        %                 display(seizuresPerDay_allFlies');
        %                 display(nansum(binnedSeizureMat_singleCohort));
        %variable seizuresPerDay_allFlies contains the correct numbers.
        binnedSleep_ZTtime_allCohorts(1:size(binnedSleep_ZTtime_singleCohort,1),nextFlyIndex:(nextFlyIndex+fliesInCohort-1)) = binnedSleep_ZTtime_singleCohort;
        binnedSleep_allCohorts(1:size(binnedSleep_ZTtime_singleCohort,1),nextFlyIndex:(nextFlyIndex+fliesInCohort-1)) = binnedSleepMat_singleCohort;
        %         display(['binned seizures single cohort: ' num2str(nansum(nansum(binnedSeizureMat_singleCohort)))]);
        %         display(['hist single cohort: ' num2str(sum(hkPerSeizureHist))]);
        binnedSeizures_allCohorts(1:size(binnedSleep_ZTtime_singleCohort,1),nextFlyIndex:(nextFlyIndex+fliesInCohort-1)) = binnedSeizureMat_singleCohort;
        %         display(['all cohorts hist: ' num2str(sum(hkPerSeizureHist_allCohorts))]);
        %         display(['binned seizures all cohorts: ' num2str(nansum(nansum(binnedSeizures_allCohorts)))]);
        binnedHkEvents_allCohorts(1:size(binnedSleep_ZTtime_singleCohort,1),nextFlyIndex:(nextFlyIndex+fliesInCohort-1))=binnedHkEvent_singleCohort;
        binnedSeizureMinutes_allCohorts(1:size(binnedSleep_ZTtime_singleCohort,1),nextFlyIndex:(nextFlyIndex+fliesInCohort-1))= binnedSeizureMinutes_singleCohort;
        nextFlyIndex = nextFlyIndex+fliesInCohort;
        
        figure(1);
        for(ai = 1:size(seizureMat,1)), %numel(arenaNums_num)),
            %Scatter plots
            subplot(2,4,7); %Number of hyperkinetic movements vs seizure duration
            seizureDat = seizureMat{ai};
            %             display(size(seizureDat));
            if(size(seizureDat,1)>0),
                seizureDuration_min = seizureDat(:,2)*24*60;
                plot(seizureDuration_min,seizureDat(:,3),'o','MarkerSize',2,'Color',groupColors(gi,:)); hold on;
                
                % From processCohort_v5.m:
                %         ZT_day0_datenum = datenum(ZT0_day0_vec);
                %         ZTtime_offsetByDay = (seizureOnsetDurationNumHK(:,1)-ZT_day0_datenum)*24;
                %         hk_ZTtime_offsetByDay = (hyperkinetic_startTimestamps-ZT_day0_datenum)*24;
                %         timestamps_thisArena_offsetByDay = (timestamps_thisArena-ZT_day0_datenum)*24;
                %         firstLastTimestamp_offsetByDay(ai,1) =timestamps_thisArena_offsetByDay(1);
                %         firstLastTimestamp_offsetByDay(ai,2) =timestamps_thisArena_offsetByDay(end);
                % firstLastTimestamp_offsetByDay(ai,3) =ZT0_day0_datenum;
                %
                % Want to output seizureOutputTime in the second
                % column of seizureMatToWrite:
                seizureOnset_hoursSinceZT0 = (seizureDat(:,1)-timestampsStartEnd_offsetByDay_singleCohort(ai,3))*24;
                seizureMatToWrite = [seizureOnset_hoursSinceZT0 mod(seizureOnset_hoursSinceZT0,24) seizureDuration_min seizureDat(:,3)];
                for(si = 1:size(seizureMatToWrite)),
                    if(~isnan(seizureMatToWrite(si,2))),
                        fprintf(fID_seizures,[groupLabel{gi,1} ' ' num2str(seizureMatToWrite(si,:)) char(10)]);
                    end;
                end;
                subplot(2,4,8); %Number of hyperkinetic movements/min of seizure per seizure duration.
                hkPerSeizureMin = seizureDat(:,3)./seizureDuration_min;
                
                [maxVal, maxIndex] = max(hkPerSeizureMin);
                plot(seizureDuration_min,hkPerSeizureMin,'o','MarkerSize',2,'Color',groupColors(gi,:)); hold on;
                
            end;
            clear seizureDat;
            clear seizureMatToWrite;
        end;
    end;
    end;
    
    toc
    
    subplot(2,4,1)
    plot(seizureDurationHistogram_bins_sec,seizureDurationHist_allCohorts,'-o','MarkerSize',2,'Color',groupColors(gi,:)); hold on;
    grid on; axis square;
    ylabel(['# of seizures']); xlabel(['Duration (s)']);
    xlim([seizureDurationHistogram_bins_sec(1) seizureDurationHistogram_bins_sec(end)]);
    numLiveFlies = num2str(sum(~isnan(seizuresPerDay_allFlies)));
    
    subplot(2,4,2);
    plot(hkPerSeizure_bins,hkPerSeizureHist_allCohorts,'-o','MarkerSize',2,'Color',groupColors(gi,:)); hold on;
    grid on; axis square;
    xlim([hkPerSeizure_bins(1) hkPerSeizure_bins(end)]);
    ylabel(['# of seizures']); xlabel(['# hyperkinetic event/seizure']);
    title(strrep(outputName,'_',' '));
    
    subplot(2,4,3);
    plot(seizure_hkPerMin_histogramBins,hkPerMinHist_allCohorts,'-o','MarkerSize',2,'Color',groupColors(gi,:)); hold on;
    grid on; axis square;
    xlabel(['# hyperkinetic events/min of seizure']);
    xlim([seizure_hkPerMin_histogramBins(1) seizure_hkPerMin_histogramBins(end)]);
    ylabel(['# of seizures']);
    
    % Category, n_s_e_i_z_u_r_e, N_f_l_y
    subplot(2,4,4);
    interval = 1/numGroups;
    n_text =  [groupLabel{gi,1} ' (n_s_z = ' num2str(sum(seizureDurationHist_allCohorts)) ...
        ', N_f_l_y = ' num2str(numLiveFlies) ')']; % ' flies'];
    text(0,interval*gi,n_text,'Color',groupColors(gi,:));
    set(gca,'XTick',[],'YTick',[]);
    
    subplot(2,4,5);
    %Time between hk events.
    plot(interHKeventInterval_bins_sec,interHKeventInterval_allCohorts,'-o','MarkerSize',2,'Color',groupColors(gi,:)); hold on;
    grid on; axis square;
    ylabel(['# hyperkinetic events']);
    xlabel(['Interevent interval (s)']);
    subplot(2,4,6);
    %Time between seizures.
    plot(interseizureInterval_bins_hrs,interseizureInterval_allCohorts,'-o','MarkerSize',2,'Color',groupColors(gi,:)); hold on;
    grid on; axis square;
    ylabel(['# seizures']);
    xlabel(['interseizure interval (hrs)']);
    
    subplot(2,4,7);
    grid on; axis square;
    xlabel(['Seizure duration (min)']); ylabel(['# hyperkinetic movements']);
    subplot(2,4,8);
    grid on; axis square;
    xlabel(['Seizure duration (min)']); ylabel(['#hkEvents/min seizure']);
    %f.Position = [100 100 1200 600];%
    % h = gcf;
    
    % set(gcf,'Units','Pixel','Position',f.Position); %[400 100 1200 600]);
    
    % Move the save function to after both pictures have been written as well as all groups.
    % cd(primedir);
    % % imwrite(figure(1),[outputName '.png']);
    % saveas(h,[outputName '.png']); %,figure(1));
    % %print(gcf,'-dpng','-r300','-painters',[outputName '.png']);
    
    %% Figure(2) is for 30 min profile of sleep vs seizure.
    % binnedSleep_allCohorts
    % binnedSleep_ZTtime_allCohorts
    
    % First need to account for offsets in starting time:
    binnedSleep_ZTtime_allCohorts = binnedSleep_ZTtime_allCohorts(:,1:(nextFlyIndex-1));
    binnedSleep_allCohorts = binnedSleep_allCohorts(:,1:(nextFlyIndex-1));
    [minStartZT,minStartFlyIndex] = min(binnedSleep_ZTtime_allCohorts(1,:));
    [maxStartZT,maxStartFlyIndex] = max(binnedSleep_ZTtime_allCohorts(1,:));
    binnedSleep_allCohorts_offset = NaN(size(binnedSleep_allCohorts));
    binnedSeizures_allCohorts_offset = NaN(size(binnedSeizures_allCohorts));
    binnedHkEvents_allCohorts_offset = NaN(size(binnedHkEvents_allCohorts));
    binnedSeizureMinutes_allCohorts_offset = NaN(size(binnedSeizureMinutes_allCohorts));
    binnedZT_allCohorts_offset = NaN(size(binnedSleep_allCohorts_offset));
    preciseNumDays = (timestampsStartEnd_offsetByDay(:,2)-timestampsStartEnd_offsetByDay(:,1))/24;
    
    %     if(size(binnedSleep_allCohorts,2)>0),
    maxNumDays = ceil(max(preciseNumDays));
        if(isnan(maxNumDays)),
        maxNumDays = 7; %display(maxNumDays);
        end;
%     try,
    ldPhaseToWrite = NaN(size(binnedSleep_allCohorts,2),2*maxNumDays+1);
%     catch,
%         display('urk');
%     end;
%     %First and last column in ldPhaseToWrite contains the first and last
    %complete ZT bins.
    for(fi = 1:size(binnedSleep_allCohorts,2)),

        thisFlyZT = binnedSleep_ZTtime_allCohorts(:,fi);
        firstIndex = find(~isnan(thisFlyZT),1,'first');
        lastIndex =  find(~isnan(thisFlyZT),1,'last');
        isNumIndices = firstIndex:lastIndex;
        thisFlyZT = thisFlyZT(isNumIndices);
        thisFlyZT = thisFlyZT(2:(end-1));

        thisFlyDat = binnedSleep_allCohorts(:,fi);
        isNumIndices = find(~isnan(thisFlyDat));
        thisFlyDat = thisFlyDat(isNumIndices);
        thisFlyDat = thisFlyDat(2:(end-1)); %Removal of assumed partial first and and last bin.
        
        thisFlySeizureCount = binnedSeizures_allCohorts(:,fi);
        thisFlySeizureCount = thisFlySeizureCount(isNumIndices);
        thisFlySeizureCount = thisFlySeizureCount(2:(end-1));
        
        thisFlyHkCount = binnedHkEvents_allCohorts(:,fi);
        thisFlyHkCount = thisFlyHkCount(isNumIndices);
        thisFlyHkCount = thisFlyHkCount(2:(end-1)); %Removal of assumed partial first and and last bin.
        
        thisFlyBinnedSeizureMins = binnedSeizureMinutes_allCohorts(:,fi);
        thisFlyBinnedSeizureMins = thisFlyBinnedSeizureMins(isNumIndices);
        thisFlyBinnedSeizureMins = thisFlyBinnedSeizureMins(2:(end-1));
        
        if(binnedSleep_ZTtime_allCohorts(1,fi)>minStartZT),
            ZT_IndexOffset = find(binnedSleep_ZTtime_allCohorts(:,minStartFlyIndex)==thisFlyZT(1),1,'first');
            endIndex = ZT_IndexOffset+numel(thisFlyDat)-1;
        else,
            ZT_IndexOffset = 1;
            endIndex = numel(thisFlyDat);
        end;
        if(endIndex>size(binnedSleep_allCohorts_offset,1)),
            temp = binnedSleep_allCohorts_offset;
            binnedSleep_allCohorts_offset = NaN(endIndex,size(binnedSleep_allCohorts_offset,2));
            binnedSleep_allCohorts_offset(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = binnedSeizures_allCohorts_offset;
            binnedSeizures_allCohorts_offset = NaN(size(binnedSleep_allCohorts_offset));
            binnedSeizures_allCohorts_offset(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = binnedHkEvents_allCohorts_offset;
            binnedHkEvents_allCohorts_offset = NaN(size(binnedHkEvents_allCohorts_offset));
            binnedHkEvents_allCohorts_offset(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
            temp = binnedSeizureMinutes_allCohorts_offset;
            binnedSeizureMinutes_allCohorts_offset(1:size(temp,1),1:size(temp,2)) = temp;
            clear temp;
        end;
        %
        % Before we save thisFlyDat, need to figure out if/when it died and set
        % that to NaNs
        % Also need to save time of death for the compass plot.
        if(sum(thisFlyDat==1)>0),
            [durations,starts,ends] = computeBinaryDurations(thisFlyDat==1);
            deathIndex = find(durations>(sleepDeathCutoff_hrs*2)); %Each bin is 30 minutes, so each hour is 2 bins
            if(~isempty(deathIndex)),
                deathTimeBin = starts(deathIndex(end));
                if(~isempty(deathIndex)&& (ends(deathIndex(end))==numel(thisFlyDat)))
                    thisFlyDat(deathTimeBin:ends(deathIndex((end)))) = -1;
                end;
            else,
                deathTimeBin = numel(thisFlyDat)+1;
            end;
            %If the fly died, then we also want to renormalize the seizuresPerDay_allFlies to account for the time of death.
            numDays = preciseNumDays(fi);
            %What are hte pros and cons of computing numDays here as
            %opposed to with the lastTimeStamp vs firstTimestamp?
            %Well, this is going to be less accurate by 2 to 58 minutes?
            numDaysAlive = (deathTimeBin-1)/48;
            seizuresPerDay_normalizedForDeath = seizuresPerDay_allFlies(fi)*numDays/numDaysAlive;
            if(seizuresPerDay_normalizedForDeath~=seizuresPerDay_allFlies(fi)),
                display('here');
            end;
            seizuresPerDay_allFlies(fi) = seizuresPerDay_normalizedForDeath;
            
            % sleepPerDay_flyVsSleepType = NaN(size(binnedSeizures_allCohorts,2),3); %24hrSleep,daySleep,nightSleep,days
            % thisFlyDat: contains sleep data in normalized 30 min bins.
            % thisFlyZT: corresponding time
            thisFly_24hrSleep = sum(thisFlyDat(1:(deathTimeBin-1))*30)/numDaysAlive;
            if(thisFly_24hrSleep<0),
                display('sadness.');
            end;
            sleepPerDay_flyVsSleepType(fi,1) = thisFly_24hrSleep;
            thisFlyZT_mod24 = mod(thisFlyZT(1:(deathTimeBin-1)),24);
            dayIndices = find(thisFlyZT_mod24<12);
            nightIndices = find(thisFlyZT_mod24>=12);
            sleepPerDay_flyVsSleepType(fi,2) = sum(thisFlyDat(dayIndices)*30)/numDaysAlive;
            sleepPerDay_flyVsSleepType(fi,3) = sum(thisFlyDat(nightIndices)*30)/numDaysAlive;
            
            thisFlyZT_mod12 = mod(thisFlyZT(1:(deathTimeBin-1)),12);
            %ldPhaseToWrite:
            ldPhaseToWrite(fi,1) = thisFlyZT(1);
            phaseBoundaryIndices = find(thisFlyZT_mod12==0);
            for(pIndex = 1:numel(phaseBoundaryIndices)),
                if(pIndex==1),
                    firstBinIndex = 1;
                else,
                    firstBinIndex = phaseBoundaryIndices(pIndex-1);
                end;
                if(pIndex~=numel(phaseBoundaryIndices)),
                    lastBinIndex = phaseBoundaryIndices(pIndex);
                else,
                    lastBinIndex = deathTimeBin-1; %numel(thisFlyZT);
                end;
                %                 lastBinIndex = min(lastBinIndex,
                ldPhaseToWrite(fi,pIndex+1) = sum(thisFlyDat(firstBinIndex:lastBinIndex)*30);
            end;
            ldPhaseToWrite(fi,end) = thisFlyZT(end);
        else,
            % Arena with no data was selected - dead at the start of
            % the video?
        end;
        binnedSleep_allCohorts_offset(ZT_IndexOffset:endIndex,fi) = thisFlyDat;
        binnedZT_allCohorts_offset(ZT_IndexOffset:endIndex,fi) = thisFlyZT;
        binnedSeizures_allCohorts_offset(ZT_IndexOffset:endIndex,fi) = thisFlySeizureCount;
        binnedHkEvents_allCohorts_offset(ZT_IndexOffset:endIndex,fi) = thisFlyHkCount;
        binnedSeizureMinutes_allCohorts_offset(ZT_IndexOffset:endIndex,fi) = thisFlyBinnedSeizureMins;
    end;
    %     end;
    
    if(numel(binnedZT_allCohorts_offset)>0),
%         binnedZT_allCohorts_offset = 0:0.5:(maxNumDays*24);
%         binnedZTtime = binnedZT_allCohorts_offset(:);
%     else,
        binnedZTtime = max(binnedZT_allCohorts_offset,[],2);
        
    end;
    try,
    lastNumIndex = find(~isnan(binnedZTtime) & binnedZTtime>0,1,'last');
    catch,
        display('meep');
    end;
%     if(lastNumIndex>size(binnedSleep_allCohorts_offset,1))
    binnedZTtime = binnedZTtime(1:lastNumIndex);
    binnedSleep_allCohorts_offset=binnedSleep_allCohorts_offset(1:lastNumIndex,:);
    
    %% 30 min bins (plotting)!
    h2 = figure(2);
    subplot(4,1,1); %First row: sleep
    liveFlyMat = binnedSleep_allCohorts_offset; %(1:lastNumIndex,:);
    deadFlyIndices = find(liveFlyMat==-1);
    binnedSleep_allCohorts_offset(deadFlyIndices) = NaN;
    plot(binnedZTtime,nanmean(binnedSleep_allCohorts_offset*30,2),'Color',groupColors(gi,:)); hold on;
    xlim([binnedZTtime(1) binnedZTtime(end)]);
    
    ylabel(['Sleep (min)/30 min bin']);
    ZTlabels = mod(binnedZTtime,24);
    niceBinLabels = mod(binnedZTtime,6); %Look for where to start to get XTickLabels at timepoints that are divisible by 6.
    niceBinLabelOffset = find(niceBinLabels==0,1);
    try,
    set(gca,'XTickLabel',ZTlabels(niceBinLabelOffset:12:end),'XTick',binnedZTtime(niceBinLabelOffset:12:end));
    catch,
        display('meep');
    end;
    title(strrep(outputName,'_',' '));
    grid on;
    
    subplot(4,1,2); %This is where we will add the minutes plot.
    % Total minutes of seizure - when I'm outputting it to text, probably
    % also output the number of live flies because I feel like someday
    % Vishnu will want to have that information.
    summedSeizureMinPerBin = nansum(binnedSeizureMinutes_allCohorts_offset(1:lastNumIndex,:),2);
    plot(binnedZTtime,summedSeizureMinPerBin,'Color',groupColors(gi,:)); hold on;
    %     xlabel(['Binned ZT time']);
    ylabel(['Total min seizure/bin']);
    set(gca,'XTickLabel',ZTlabels(niceBinLabelOffset:12:end),'XTick',binnedZTtime(niceBinLabelOffset:12:end));
    grid on;
    
    subplot(4,1,3);
    summedSeizurePerBin = nansum(binnedSeizures_allCohorts_offset(1:lastNumIndex,:),2);
    plot(binnedZTtime,summedSeizurePerBin,'Color',groupColors(gi,:)); hold on;
    ylabel(['# seizures/bin']);
    set(gca,'XTickLabel',ZTlabels(niceBinLabelOffset:12:end),'XTick',binnedZTtime(niceBinLabelOffset:12:end));
    grid on;
    
    subplot(4,1,4);
    plot(binnedZTtime,nansum(binnedHkEvents_allCohorts_offset(1:lastNumIndex,:),2),'Color',groupColors(gi,:)); hold on;
    ylabel(['# hk events/bin']);
    %     ZTlabels = mod(binnedZTtime,24);
    %     niceBinLabels = mod(binnedZTtime,6); %Look for where to start to get XTickLabels at timepoints that are divisible by 6.
    %     niceBinLabelOffset = find(niceBinLabels==0,1);
    set(gca,'XTickLabel',ZTlabels(niceBinLabelOffset:12:end),'XTick',binnedZTtime(niceBinLabelOffset:12:end));
    grid on;
    
    figure(4);
    subplot(2,1,2); %Number of recorded flies.
    recordedFliesPerBin = sum(~isnan(liveFlyMat(1:lastNumIndex,:)),2);
    plot(binnedZTtime,recordedFliesPerBin,'Color',groupColors(gi,:),'LineWidth',(size(groupColors,1)-gi)*2+1); hold on;%,'LineWidth'); hold on;
    liveFliesPerBin = sum(liveFlyMat(1:lastNumIndex,:)>-1,2);
    xlim([binnedZTtime(1) binnedZTtime(end)]);
    ylim([0 max(liveFliesPerBin)+1]);
    xlabel(['Binned ZT time']);
    ylabel(['# of recorded flies']);
    set(gca,'XTIckLabel',ZTlabels(niceBinLabelOffset:12:end),'XTick',binnedZTtime(niceBinLabelOffset:12:end));
    grid on;
    
    subplot(2,1,1); %Number of live flies.
    plot(binnedZTtime,liveFliesPerBin,'LineWidth',(size(groupColors,1)-gi)*2+1,'Color',groupColors(gi,:)); hold on;
    xlim([binnedZTtime(1) binnedZTtime(end)]);
    ylim([0 max(liveFliesPerBin)+1]);
    %     xlabel(['Binned ZT time']);
    ylabel(['# of live flies']);
    % The next three lines were already written and executed for the previous two subplots.
    %     ZTlabels = mod(binnedZTtime,24);
    %     niceBinLabels = mod(binnedZTtime,6); %Look for where to start to get XTickLabels at timepoints that are divisible by 6.
    %     niceBinLabelOffset = find(niceBinLabels==0,1);
    set(gca,'XTIckLabel',ZTlabels(niceBinLabelOffset:12:end),'XTick',binnedZTtime(niceBinLabelOffset:12:end));
    grid on;
    deadFliesPerBin = recordedFliesPerBin-liveFliesPerBin;
    deltaDeath = diff(deadFliesPerBin);
    deltaDeathIndices = find(deltaDeath>0);
    deadFliesPerBin = zeros(size(deadFliesPerBin));
    deadFliesPerBin(deltaDeathIndices+1) = deltaDeath(deltaDeathIndices);
    deadFlyTimes = ZTlabels(deltaDeathIndices+1);
    
    %% Compass plots require the end points of the arrows in x,y (not
    % r*sin(theta)).
    % r is the value in the bin.
    % Theta is the bin/24*2*pi
%     figure(3);
%     subplot(1,2,1); %Time of seizure
    numDays = ceil(max(binnedZTtime)/24);
    nanPadded_summedSeizurePerBin = NaN(numDays*48,1);
    nanPadded_summedSeizurePerBin(1:size(summedSeizurePerBin,1)) = summedSeizurePerBin;
    reshaped_summedSeizurePerBin = reshape(nanPadded_summedSeizurePerBin,48,numDays);
    
    
    if(numel(binnedZTtime)<48),
        lastBinIndex = numel(binnedZTtime);
    else,
        lastBinIndex = 48;
    end;
    thetaBins = binnedZTtime(1:lastBinIndex)/24*2*pi;
%     thetaBins = repmat(1,size(thetaBins,1),size(thetaBins,2))-thetaBins;
%     [u_s,v_s] = pol2cart(thetaBins,nansum(reshaped_summedSeizurePerBin,2));
%     p=compass(u_s,v_s); hold on;
%     set(p,'color',groupColors(gi,:));
%     
%     if(~exist('ZT0_yax','var')),
%         ZT0_yax = max(v_s);
%     elseif(max(v_s)>ZT0_yax),
%         ZT0_yax = max(v_s);
%     end;
%     
%     if(gi==size(groupColors,1)),
%         set(gcf,'Units','Pixel','Position',[400 100 1200 600]);
%         text(0,ZT0_yax+1,'ZT 0');
%         text(0,-1*ZT0_yax-1,'ZT 12');
%         title(['Time of seizure']);
%     end;
%     %
%     subplot(1,2,2); %Time of death;
    nanPadded_deathBins = NaN(size(nanPadded_summedSeizurePerBin));
    nanPadded_deathBins(1:size(deadFliesPerBin,1),1:size(deadFliesPerBin,2)) = deadFliesPerBin;
    reshaped_deathBins = reshape(nanPadded_deathBins,48,numDays);
    deathBins = NaN(size(thetaBins));
    deadFlyTimes_uniqueThetas = unique(deadFlyTimes)/24*2*pi;
    for(ti = 1:numel(deadFlyTimes_uniqueThetas)),
        numDead = sum(deadFlyTimes==deadFlyTimes_uniqueThetas(ti));
        thetaIndex = find(thetaBins==deadFlyTimes_uniqueThetas(ti));
        deathBins(thetaIndex)=numDead;
    end;
    %%
    save([outputName '_' groupLabel{gi,1} '.mat'],'-mat','hkPerSeizure_bins','hkPerSeizureHist_allCohorts','seizureDurationHistogram_bins_sec',...
        'seizureDurationHist_allCohorts','seizure_hkPerMin_histogramBins','seizuresPerDay_allFlies');
    
    
    %% Figure 5: Didn't want to comment out the compass plot, but experimenting with polar plots for aesthetic reasons.
    % polar(theta, rho);
    figure(5);
    
    subplot(1,3,1); %Time of seizure
    rhoSeizures = nansum(reshaped_summedSeizurePerBin,2);
    foldMegaBin = 6; %6 30 min bins per wedge.
    megaThetaBins = thetaBins(1:foldMegaBin:end);

    rhoSeizures = nansum(reshape(rhoSeizures(:),foldMegaBin,numel(rhoSeizures)/foldMegaBin)); %,2);
    p=polarplot([megaThetaBins(:); megaThetaBins(1)],[rhoSeizures(:); rhoSeizures(1)]);
    ax = gca;
    ax.ThetaDir='clockwise';
    ax.ThetaZeroLocation='top';
    ax.ThetaTick = [0:30:330];
    ax.ThetaTickLabel = [0:2:22]; %megaThetaBins*24/2/pi;
    hold on;
    set(p,'Color',groupColors(gi,:),'LineWidth',2);
    if(~exist('ZT0_yax_maxRho','var')),
        ZT0_yax_maxRho = max(rhoSeizures);
    elseif(max(rhoSeizures)>ZT0_yax_maxRho),
        ZT0_yax_maxRho = max(rhoSeizures);
    end;
    %Here, the r-axis represents the number of seizures
    rTickInterval = ceil(ZT0_yax_maxRho/5);
    rTickList = [rTickInterval:rTickInterval:(rTickInterval*5)];
    rTickList = [rTickInterval:rTickInterval:(rTickInterval*5)];
    if(numel(rTickList)==0)
        rTickList = [0 2]; %rTickInterval];
    end;
    %     rTickInterval = ceil(ZT0_yax/5);
    %     rTickList = [rTickInterval:rTickInterval:(rTickInterval*5)];
    %If ZT0_yax = 10, then rTickList would be 2:4:6:8:10
    try,
        set(gca,'rtick',rTickList);
    catch
        rlim([min(rTickList) max(rTickList)]);
    end;
    
    if(gi==size(groupColors,1)),
        set(gcf,'Units','Pixel','Position',[400 100 1200 600]); %Because this is the first group and the first subplot.
%         text(0,ZT0_yax+1,'ZT 0');
%         text(0,-1*ZT0_yax-1,'ZT 12');
        title(['Seizure Onset Time']);
    end;
    %Run the Rayleigh test for circular uniformity
    w = rhoSeizures(:);
    d = mean(diff(megaThetaBins));
    [pval,z] = circ_rtest(w,w,d);
    text(0,-max(rTickList)-rTickInterval*(gi-1),['Onset Time: p = ' num2str(pval)],'Color',groupColors(gi,:));
    %----------------------------------------------------------
    subplot(1,3,2); %Summed seizure time
    %         summedSeizureMinPerBin = nansum(binnedSeizureMinutes_allCohorts_offset,2);
    %     plot(binnedZTtime,summedSeizureMinPerBin,'Color',groupColors(gi,:)); hold on;
    nanPadded_summedMinutesSeizingPerBin = NaN(numDays*48,1);
    nanPadded_summedMinutesSeizingPerBin(1:size(summedSeizureMinPerBin,1)) = summedSeizureMinPerBin;
    rhoSummedMinSeizurePerBin = nansum(reshape(nanPadded_summedMinutesSeizingPerBin,48,numDays),2);
    rhoMinutesSeizingBins = nansum(reshape(rhoSummedMinSeizurePerBin(:),foldMegaBin,numel(rhoSummedMinSeizurePerBin(:))/foldMegaBin));
    p=polarplot([megaThetaBins(:); megaThetaBins(1)],[rhoMinutesSeizingBins(:); rhoMinutesSeizingBins(1)]);
    ax = gca;
    ax.ThetaDir='clockwise';
    ax.ThetaZeroLocation='top';
    ax.ThetaTick = [0:30:330];
    ax.ThetaTickLabel = [0:2:22]; 
%     ax.ThetaTickLabel = megaThetaBins*24/2/pi;
    hold on;
    hardColor = groupColors(gi,:);
    set(p,'Color',hardColor,'LineWidth',2);
    if(~exist('ZT0_yax_rhoSeizeTime','var')),
        ZT0_yax_rhoSeizeTime = max(rhoMinutesSeizingBins(:));
    elseif(max(rhoMinutesSeizingBins(:))>ZT0_yax_rhoSeizeTime),
        ZT0_yax_rhoSeizeTime = max(rhoMinutesSeizingBins(:));
    end;
    %Here, the r-axis represents the number of seizures
    rTickInterval = 30; %ceil(ZT0_yax_rhoSeizeTime/30);
    r_upperLim = ceil(ZT0_yax_rhoSeizeTime/rTickInterval)*rTickInterval;
    rTickList = [rTickInterval:rTickInterval:r_upperLim];
    if(numel(rTickList)==1)
        rTickList = [0 rTickList];
    end;
    try,
        set(gca,'rtick',rTickList);
    catch
        rlim([min(rTickList) max(rTickList)]);
    end;
    if(gi==size(groupColors,1)),
        title(['Minutes seizing']);
    end;

    w = rhoMinutesSeizingBins(:);
    d = mean(diff(megaThetaBins));
    [pval,z] = circ_rtest(w,w,d);
    %     text(200,10+10*(gi-1),['Minutes: p = ' num2str(pval)],'Color',groupColors(gi,:));
    textOffset = 30; %min(-30,rTickInterval);
%     display(rTickList)
    try,
    text(0,-max(rTickList)-textOffset*(gi-1),['Minutes: p = ' num2str(pval)],'Color',groupColors(gi,:));
    catch,
    text(0,-2*textOffset*(gi-1),['Minutes: p = ' num2str(pval)],'Color',groupColors(gi,:));
    end;
    %----------------------------------------------------------
    subplot(1,3,3); %Time of death;
    rhoDeathBins = nansum(reshaped_deathBins,2);
    rhoDeathBins = nansum(reshape(rhoDeathBins(:),foldMegaBin,numel(rhoDeathBins)/foldMegaBin)); %,2);
    
    %     [u_s,v_s] = pol2cart(thetaBins,nansum(reshaped_deathBins,2));
    p=polarplot([megaThetaBins(:); megaThetaBins(1)],[rhoDeathBins(:); rhoDeathBins(1)]);
    ax = gca;
    ax.ThetaDir='clockwise';
    ax.ThetaZeroLocation='top';
%     ax.ThetaTickLabel = megaThetaBins*24/2/pi;

    ax.ThetaTick = [0:30:330];
    ax.ThetaTickLabel = [0:2:22]; 
    hold on;
    hardColor = groupColors(gi,:);
    %     if(gi==1),
    %         hardColor = [0 0 0];
    %     else,
    %         hardColor = [0.5 0.5 0.5];
    %     end;
    set(p,'Color',hardColor,'LineWidth',2);
    if(~exist('ZT0_yax_death','var')),
        ZT0_yax_death = max(rhoDeathBins(:));
    elseif(max(rhoDeathBins(:))>ZT0_yax_death),
        ZT0_yax_death = max(rhoDeathBins(:));
    end;
    rTickInterval = ceil(ZT0_yax_death/5);
    rTickList = [rTickInterval:rTickInterval:(rTickInterval*5)];
    try,
        set(gca,'rtick',rTickList);
    catch
        rlim([min(rTickList) max(rTickList)]);
    end;
    %    ZT0_yax_death = 10;
    if(gi==size(groupColors,1)),
        %    set(gcf,'Units','Pixel','Position',[400 100 1200 600]);
%         text(0,ZT0_yax_death+1,'ZT 0');
%         text(0,-1*ZT0_yax_death-1,'ZT 12');
        title(['Time of death']);
    end;
    w = rhoDeathBins(:);
    d = mean(diff(megaThetaBins));
    [pval,z] = circ_rtest(w,w,d);
%     text(400,10+10*(gi-1),['Death: p = ' num2str(pval)],'Color',groupColors(gi,:));
% textY = -max(rTickList)-1; %rTickInterval*(gi-1);
% if(isempty(textY))
    textY = -1*(gi-1);
% end;
    text(0,textY,['Death: p = ' num2str(pval)],'Color',groupColors(gi,:));

    
    %% At minimum, Vishnu probably needs the text outputs for the 30 min bins as well as the day vs night vs total sleep.
    % So we have three 30 min bin plots that are important:
    %
    % SLEEP:
    % plot(binnedZTtime,nanmean(binnedSleep_allCohorts_offset*30,2),'Color',groupColors(gi,:)); hold on;
    % SUMMED SEIZURES:
    % plot(binnedZTtime,summedSeizurePerBin,'Color',groupColors(gi,:)); hold on;
    %
    % Assuming Vishnu doesn't want HK events on 30 min bins?
    %
    % Two files (v17):
    output30minbins_filename = [outputName '_' groupLabel{gi,1} '_30minBins.txt'];
    outputSleepTotals = [outputName '_' groupLabel{gi,1} '_sleepSeizeTotals.txt'];
    %
    % 30 min bin files will consist of: binnedZT time, nanmean, SEM,
    % summedSeizures
    binnedSleep_allCohorts_byMin = binnedSleep_allCohorts_offset*30;
    mat2write_30minbins = NaN(size(binnedZTtime,1),5);
    mat2write_30minbins(:,1) = binnedZTtime;
    mat2write_30minbins(:,2) = nanmean(binnedSleep_allCohorts_byMin,2);
    mat2write_30minbins(:,3) = nanstd(binnedSleep_allCohorts_byMin,[],2)./sqrt(liveFliesPerBin);
    mat2write_30minbins(:,4) = summedSeizurePerBin;
    mat2write_30minbins(:,5) = summedSeizureMinPerBin; %This is where we will save the total minutes
    mat2write_30minbins(:,6) = liveFliesPerBin; %# of flies, in case Vishnu changes his mind.
    mat2write_30minbins(:,7) = recordedFliesPerBin; %# of flies, in case Vishnu changes his mind.
    
    cd(primedir);
    
    bins_fID =fopen(output30minbins_filename,'w');
    fprintf(bins_fID,['ZTtime mean sem summed#seizures summedMinSeizures #liveFlies #recordedFlies' char(10)]);
    for(lineI = 1:size(mat2write_30minbins,1)),
        fprintf(bins_fID,[num2str(mat2write_30minbins(lineI,:)) char(10)]);
    end;
    fclose(bins_fID);
    
    %% Now open a sheet for writing sleep, day, night, seizuresPerDay.
    %
    % Although there is a numDays that is set just prior to compass
    % plots, this computes a single numDays for the entire matrix of
    % all flies, without taking into consideration that there might be
    % different offsets. Thus, need to recompute numDays while taking
    % into consideration the number of nanBins at the start of the
    % recording.
    
    %     plot(binnedZTtime,nanmean(binnedSleep_allCohorts_offset*30,2),'Color',groupColors(gi,:)); hold on;
    %     set(gca,'XTIckLabel',ZTlabels(niceBinLabelOffset:12:end),'XTick',binnedZTtime(niceBinLabelOffset:12:end));
    %     plot(binnedZTtime,liveFliesPerBin,'LineWidth',(size(groupColors,1)-gi)*2+1,'Color',groupColors(gi,:)); hold on;
    
    sleepTotals_fID = fopen(outputSleepTotals,'w');
    fprintf(sleepTotals_fID,['avg_24h_sleep(min) avg_day_sleep(min) avg_night_sleep(min) seizuresPerDay' char(10)]);
    %     seizuresPerDay_allFlies(:,end);
    for(lineI = 1:size(sleepPerDay_flyVsSleepType,1)),
        if(~isnan(sleepPerDay_flyVsSleepType(lineI,1))),
            lineToPrint = [num2str(sleepPerDay_flyVsSleepType(lineI,:)) ' ' num2str(seizuresPerDay_allFlies(lineI,:)) char(10)];
            fprintf(bins_fID,lineToPrint);
        end;
    end;
    fclose(sleepTotals_fID);
    
    %In addition to the average 24h, day, and night sleep, Vishnu asked for
    %the sleep to be broken down by day:
    %     binnedZTtime,nanmean(binnedSleep_allCohorts_offset*30;
    sleepPerLDPhase = [outputName '_' groupLabel{gi,1} '_sleepPerLDphase.txt'];
    %Here I actually AM discarding the first and last bins.
    sleepPerLDPhase_fID = fopen(sleepPerLDPhase,'w');
    % Generate heading:
    %         ldHeadings = ['FirstCompleteZTbin Day1 Night1 Day2 ... DayN LastCompleteZTbin'];
    ldHeadings = ['FirstCompleteZTbin'];
    ceilingNumDays = ceil(binnedZTtime(end)/24);
    for(di = 1:ceilingNumDays);
        dayText = num2str(ceil(di/2));
        if(mod(di,2)==1),
            ldHeadings = [ldHeadings ' Day' dayText];
        else,
            ldHeadings = [ldHeadings ' Night' dayText];
        end;
    end;
    ldHeadings = [ldHeadings ' lastCompleteZTbin' char(10)];
    fprintf(sleepPerLDPhase_fID,ldHeadings);
    isNumIndices = find(~isnan(ldPhaseToWrite(:,1)));
    ldPhaseToWrite = ldPhaseToWrite(isNumIndices,:);
    for(lineI = 1:size(ldPhaseToWrite,1)),
        if(~isnan(ldPhaseToWrite(lineI,1))),
            fprintf(sleepPerLDPhase_fID,[num2str(ldPhaseToWrite(lineI,:)) char(10)]);
        end;
    end;
    fclose(sleepPerLDPhase_fID);
end;
% Useful to use imagesc when debugging.
% subplot(3,1,3);
% imagesc(~isnan(binnedSleep_allCohorts_offset(1:lastNumIndex,:))');
% A few things we want to add right now:
% 1) Check for live flies, plot #
% 2) Plot seizures
% Original plan was a third row of total sleep, day sleep, night sleep, and
% ratio of day to night sleep. However, because the first and last bins
% here are fractional, doesn't quite make sense to compute this sleep
% informatio from the binned data.
set(gcf,'Units','Pixel','Position',[400 100 1200 600]);

cd(primedir);

h = figure(1);
saveas(h,[outputName '.png']); %,figure(1));
h2 = figure(2);
set(gcf,'Units','Pixel','Position',[400 100 1200 600]);

saveas(h2,[outputName '_30minBins.png']); %,figure(1));
% h3 = figure(3);
% saveas(h3,[outputName '_compassPlots.png']); %,figure(1));
h5 = figure(5);
saveas(h5,[outputName '_' num2str(foldMegaBin) 'x30min_polar.png']); %,figure(1));
saveas(h5,[outputName '_' num2str(foldMegaBin) 'x30min_polar.fig']); %,figure(1));

%At the moment, this is being saved in terms of histograms, but if we want bar graphs with the scatter for individual flies, we'll have to make several lists.
%But the lists of seizures per cohort are being saved anyway?
%-- PROBLEM: the lists of seizures per cohort are currently being saved in a condition by condition basis.
% So if we want to go this route we will have to save a separate list/*.mat file for each of the six conditions (or for each arena?).
% This function also receives a 'seizureMat' output from each 'processCohort' call.
% seizureMat is a cell array which stores a three column matrix (seizure onset, seizure duration), number of HK events for each array.
%%
% Also need to grab seizureOnsetDurationNumHK (output by processArena) and save and write it to the matrix.
% *.ps, *.pdf, *_eventList.txt;

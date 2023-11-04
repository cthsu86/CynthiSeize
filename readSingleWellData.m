%% function readSingelWellData(varargin)
%
% I believe this is exported as an ANSI text file, with semicolon
% delimiters?
%
% Called by batchMultiWell.m

function readSingleWellData(varargin)
if(nargin==0),
    rootdir = 'D:\Vishnu\Export Files';
    filename = 'Track-20210209 Testing 24 wells-Trial     1-Arena 4-Subject 1.txt';
    fps = 30;
else,
    rootdir = varargin{1};
    filename = varargin{2};
    fps = varargin{3};
end;

cd(rootdir);

% totalNumReadings = 100; %maxDays*24*60*60*fps;
% outputMat = NaN(totalNumReadings,11);
fID = fopen(filename);
% recordingOffset = 0;
i =1;
% oi = i-recordingOffset;
% atFileEnd = 0; %Can use feof to indicate the end of the file, but then we wouldn't have the matrix preallocated properly.
% try
while(~feof(fID)), %feof(fID)),
    lineOfData = fgets(fID);
    if(~isempty(strfind(lineOfData,'Video start time'))),
        quoteIndices = strfind(lineOfData,'"');
        startDate = lineOfData(quoteIndices(end-1)+1:quoteIndices(end)-1);
%         startDate_datenum = datenum(startDate);
    elseif(~isempty(strfind(lineOfData,'Reference duration'))),
        quoteIndices = strfind(lineOfData,'"');
        durationString = lineOfData(quoteIndices(end-1)+3:quoteIndices(end)-1)
        colonIndices = strfind(durationString,':');
        numHrs = str2num(durationString(1:(colonIndices(1)-1)));
        numMinutes = str2num(durationString((colonIndices(1)+1):(colonIndices(2)-1)));
        numSeconds = floor(str2num(durationString((colonIndices(2)+1):end)));
%%        stringToParse = durationString(1:(colonIndices(end)+2))
%%        durationVec = datevec(stringToParse,'HH:MM:SS'); 
        %Datevec is wildly inaccurate for everything but the last two
        %indices, 5 and 6
        numSecs = numHrs*3600+60*numMinutes+numSeconds+1;
        totalNumReadings = ceil(numSecs*fps);
%         outputMat = NaN(totalNumReadings,
    elseif(~isempty(strfind(lineOfData,'Number of header lines'))),
        quoteIndices = strfind(lineOfData,'"');
        numHeaderLines = str2num(lineOfData(quoteIndices(end-1)+1:quoteIndices(end)-1));
    elseif(i==(numHeaderLines-1)), 
        %Line #<numHeaderLines> contains the units. I'm going to assume we don't need those for now.
        columnTitles_line = lineOfData;
        %Column Titles from representative example:
        % "Trial time";"Recording time";"X center";"Y center";"Area";"Areachange";"Elongation";
        % 1, 2, 3, 4, 5, 6, 7 => Want to save 2 through 7?
        % Followed by a bunch of Vishnu's manual
        % classifications/annotations.
        % May as well save all the classifications/annotations, since they
        % are numbers across the board.
        numColumns = numel(strfind(columnTitles_line,';'));
%         display(totalNumReadings)
        outputMat = NaN(totalNumReadings,numColumns);
    elseif(i>numHeaderLines),
        lineOfData = strrep(lineOfData,';',' ');
        lineOfData = strrep(lineOfData,'"-"','NaN');
        dataArray = str2num(lineOfData);
        try,
        outputMat(i-numHeaderLines,:) = dataArray;
        catch,
            display(lineOfData)
        end;
    end;
    if(mod(i,1000)==0),
        display(['Finished reading line ' num2str(i-numHeaderLines) ' out of ' num2str(totalNumReadings)]);
    end;
    i = i+1;
end;
fclose(fID);
save(strrep(filename,'.txt','.mat'),'columnTitles_line','outputMat','startDate','-mat');
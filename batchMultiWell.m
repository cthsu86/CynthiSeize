function batchMultiWell()

rootdir = 'D:\Video Tracking\20231024 MB122B+GtACR+ATR+Picro\Export Files';
firstFileName = 'Track-20231024 MB122B+GtACR+ATR+Picro-Trial     1-1-Subject 1.txt';
stringToReplace = '-1-'
numbersToReplace = [1:48]; %[1 3:15 17:24]; %Should include the first trial you want to run, even if it's listed in the first file name.
%Thus, to run on all 24 wells, need to set numbersToReplace to 1:24.
fps = 25;

cd(rootdir);
tic;
for(fi = 1:numel(numbersToReplace)),
    arenaNum = numbersToReplace(fi);
    filename = strrep(firstFileName, stringToReplace,['-' num2str(arenaNum) '-'])
    readSingleWellData(rootdir,filename,fps);
end;
toc



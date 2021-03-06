function improcess8(data,fastmode)
%==========================================================================
% function improcess8(data,fastmode)
%--------------------------------------------------------------------------
% IN: data structure-array
%       data.fn : cell array with movie filenames to evaluate
% (optional) data.statfile: cell array of files with statistics (e.g. avg)
%       data.fr1: cell array with number of first frame
%       data.frN: cell array with number of amount of frames
%       data.den: cell array (0: no, 1: wdenoise)
%       data.cut: data.cur{num}.lr indices; data.cur{num}.ud indices; or []
%       fastmode: 1: no picture drawing
%--------------------------------------------------------------------------
%IMPROCESS8 evaluates camera measurements stored as '*.cine'-files, whereas
%the movie filenames are stored in the variable 'data.fn{i}' with i=1..N.
%It calculates the average image of the camera frame interval starting at
%'data.fr1{i}' to 'data.frN{i}'. The average picture will be 
%saved as 'avg.tif'. Finally the average will be removed from the chosen
%pictures and saved as ['a' picture name].
%The saved images are shifted to positive values, so that the conversion
%to uint-numbers doesn't truncate the negative values. The following
%programs have to substract this shift to recover the original values
%The shift is saved in the shift.mat-file. For denoising set data.den{i}=1.
%--------------------------------------------------------------------------
% Ex: 
% data.fn{1}  = 'G:\work_20130615\rawdata\18222.cine';
% data.fr1{1} = 1;
% data.frN{1} = 5000;
% data.den{1} = 0;
% improcess8(data,0);
%--------------------------------------------------------------------------
% (C) 04.07.2013 15:17, C. Brandt
%     - changed input to filename
% (C) 07.06.2012 17:45, C. Brandt
%     - new version: renamed to improcess7.m
%     - include read cine files, improved shift-file saving
% (C) 04.06.2012 16:43, C. Brandt
%     - included reading cine-files
% (C) 17.03.2011 08:19, C. Brandt
%     - simplified averaging
% (C) 05.01.2011 11:30, C. Brandt
%     - added remainder of clusters (nrest)
%     - create wavelet decomposed video "wavdec.avi"
%     - added movie rawdata, black&white
%     - added movie wavdec, black&white
%     - added movie wavdec, color
% (C) 04.01.2011 16:50, C. Brandt
%==========================================================================

if nargin<2; fastmode=0; end

% Save start directory
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
startdir = pwd;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% FOR loop: amount of files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ldir = length(data.fn);
for ifn=1:ldir

disp(['start evaluation of movie file: ' data.fn{ifn}])

% Load camera parameters
info_cine = cineInfo(data.fn{ifn});
dt = 1/info_cine.frameRate;    

% Check if amount of claimed files is available, if not show error message
if info_cine.NumFrames < data.frN{ifn}
 error('Set number of frames is too large!')
else
  n = data.frN{ifn};
end



%==========================================================================
% Calculate Average Picture of chosen pictures
%==========================================================================
% If statistic file is provided take avg from there
if isfield(data,'statfile')
  disp('... average image method: load from movie statistic file:')
  disp(data.statfile{ifn})
  load(data.statfile{ifn});
  aver = movstat.avg;
  shift = max(max(aver));
else
  disp('... average image method: calculate avg from raw images')
  % Calculate average picture
  aver = 0;
  for i=1:n
    num = data.fr1{ifn} + i-1;       % CINE file: pic=1 means start at 0
    pic = double(cineRead(data.fn{ifn}, num));
    aver = aver + pic;
  end
  aver = aver/n;
  % save averaged image
  shift = max(max(aver));
  % Save averaged image
  fnavg = [data.fn{ifn}(1:end-5) '_avg.mat'];
  save(fnavg, 'aver','shift');
end


%==========================================================================
% Substract the average picture -> Obtain fluctuation data
%==========================================================================
disp(['load raw pictures, substract average and save ' ...
  'fluctuation data files a*.tif'])
% Remove the averaged image and save the corresponding images
  % cmin and cmax defined for finding the color limits
  cmin = +inf; cmax = -inf;
for i=1:n
  num = i-1+data.fr1{ifn};
  curpic = double(cineRead(data.fn{ifn},num));
  after = curpic-aver;
  
  % Cut pictures if wanted
  if ~isempty(data.cut{ifn}.lr)
    after = after(data.cut{ifn}.ud, data.cut{ifn}.lr);
  end
  
  if min(min(after))<cmin
    cmin = min(min(after));
  end
  if max(max(after))>cmax
    cmax = max(max(after));
  end
  % name of the saved files
  str=mkstring('a/a','0',num,n,'.tif');
  nomfin=str;
  imwrite(uint16(after+shift),nomfin,'tif');
end
clim = max([abs(cmin) abs(cmax)]);


%----------------------- Save SHIFT file with value of shift of the picture
disp('Removed average on all pictures')
%fnshift = ['shift_avg_' num2str(data.fr1{ifn}) 'ToN' num2str(n) '.mat'];
fnshift = 'shift.mat';
vid.avg = aver;
vid.shift = shift;
vid.info = 'shift contains the shift value to the originals, aver is the AVG';
save(fnshift,'vid');


% Play Video of average removed data
if ~fastmode
  figeps(12,10,1);
  tifavg = dir('a*.tif');
  for i=1:n
    num = i-1+data.fr1{ifn};
    curfile = tifavg(num).name;
    curpic = double(imread(curfile)) - shift;
    pcolor(curpic); shading flat
    disp(['time (ms): ' num2str(1e3*(i-1)*dt)]); % show time in milliseconds
    caxis(0.5*clim*[-1 1]);
    colorbar;
    colormap(pastelldeep(128))
    axis equal
    drawnow
  end
end


% Denoise if activated
if data.den{ifn} == 1
  disp('Denoise images')
  subdata.dir{1} = data.dir{ifn};
  subdata.fr1{1} = data.fr1{ifn};
  subdata.frN{1} = data.frN{ifn};
  wdenoise7(subdata,fastmode);
end


end %for-loop ifn

% Change to start directory
cd(startdir);

end %function
function matlab_entrypoint(varargin)

% This function serves as the entrypoint to the matlab part of the
% pipeline. Its purpose is to parse the command line arguments, then call
% the main functions that actually do the work.

%% Just quit, if requested - needed for docker build
if numel(varargin)==1 && strcmp(varargin{1},'quit') && isdeployed
	disp('Exiting as requested')
	exit
end


%% Parse the inputs and parameters

P = inputParser;

% Eprime log converted from Eprime's .txt output file via
% ../../src/eprime_to_csv.py
addOptional(P,'eprime_csv','')

% We also want a DICOM from the fMRI - used only to compare timestamps.
% This should be the first DICOM of the first fMRI run.
addOptional(P,'fmri_dcm','')

% We also take a numerical parameter than can be used to override the
% errors generated when eprime timestamps don't match the fmri. Note that
% when arguments are passed to compiled Matlab via command line, they all
% come as strings; so we will need to convert this to a numeric format
% later.
addOptional(P,'timeoverride','0');

% renumoverride = 1 to allow renumbering trials if they are not 1:160. This
% would happen if eprime.txt files from multiple runs (in/out of scanner)
% were concatenated. Otherwise supply renumoverride = 0.
addOptional(P,'renumoverride','0');

% Finally, we need to know where to store the outputs.
addOptional(P,'out_dir','/OUTPUTS');

% Parse
parse(P,varargin{:});

% Display the command line parameters - very helpful for running on XNAT,
% as this will show up in the outlog.
disp(P.Results)


%% Run the actual pipeline
[report_csv,summary_csv] = analyze_eprime( ...
	P.Results.eprime_csv, ...
	P.Results.fmri_dcm, ...
	P.Results.out_dir, ...
	str2double(P.Results.timeoverride), ...
	str2double(P.Results.renumoverride) ...
	);
[trial_csv,summary_csv] = hgf_fit( ...
	report_csv, ...
	summary_csv, ...
	P.Results.out_dir ...
	);
make_pdf( ...
	trial_csv, ...
	summary_csv, ...
	P.Results.out_dir ...
	);


%% Exit
% But only if we're running the compiled executable.
if isdeployed
	exit
end


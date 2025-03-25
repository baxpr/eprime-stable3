function [report_csv,summary_csv] = analyze_eprime( ...
	eprime_csv,fmri_dcm,out_dir,timeoverride,renumoverride)

% timeoverride = 1 to continue even if eprime and dicom timestamps aren't
% close enough. Otherwise supply timeoverride = 0.
%
% renumoverride = 1 to allow renumbering trials if they are not 1:80. This
% would happen if eprime.txt files from multiple runs (in/out of scanner)
% were concatenated. Otherwise supply renumoverride = 0.


%% Setup

% We know this and we don't care. We know what the modified varnames are
% and they are being used in the code
warning('off','MATLAB:table:ModifiedAndSavedVarnames');

% Turn off autodetecting duration/datetime types for reading some
% dates/times
opts = detectImportOptions(eprime_csv);
opts = setvartype(opts,{'SessionTime','SessionStartDateTimeUtc'},'char');

% Load the edat
fprintf('Eprime file: %s\n',eprime_csv);
Efull = readtable(eprime_csv,opts);

% Actual card trials are the 'Bet' subset. NOTE we assume they are
% correctly sorted (time order) already. This relies on the original
% eprime.txt file being in time order (which it is) and the trials not
% getting re-sorted by the regex stuff in eprime_to_csv.py.
Ebet = Efull(strcmp(Efull.Procedure,'Bet'),:);

% Initialize output data
Ebet.RT = Ebet.GameScreen_RT;
Ebet.RT(Ebet.RT==0) = nan;
Ebet.Outcome(strcmp(Ebet.Outcome,'?')) = {''};
Ebet.Trial = (1:height(Ebet))';
Ebet.Run = nan(height(Ebet),1);
Ebet.TrialType(:) = {' '};
Ebet.NoResponse = 1 * cellfun(@isempty,Ebet.ChosenColor);
Ebet.Switch(:) = {' '};
Ebet.WinSwitch(:) = {' '};
Ebet.WinStay(:) = {' '};
Ebet.LoseSwitch(:) = {' '};
Ebet.LoseStay(:) = {' '};
Ebet.ProbabilisticLoss(:) = nan(height(Ebet),1);
Ebet.SubOptimalDeckLoss(:) = nan(height(Ebet),1);

% We should have exactly 80 trials (2 runs, 40 trials each)
if height(Ebet) ~= 80
	error('Expected 80 trials but found %d',height(Ebet))
end

% If trials aren't numbered 1:80, we have a concatenated eprime.txt and
% need to renumber
renumberflag = 0;
if ~all(Ebet.Play_Sample==(1:80)')
	if renumoverride==1
		warning('Inconsistent trial numbering found - renumbering')
		Ebet.Play_Sample = (1:80)';
		renumberflag = 1;
	else
		error('Inconsistent trial numbering found')
	end
end

% Label FMRI sections (four runs) and verify.
Ebet.Run(Ebet.Play_Sample>=  1 & Ebet.Play_Sample<= 40) = 1;
Ebet.Run(Ebet.Play_Sample>= 41 & Ebet.Play_Sample<= 80) = 2;

if ...
		(sum(Ebet.Run==1)~=40) || ...
		(sum(Ebet.Run==2)~=40)
	error('Found other than 40 trials per run: %d %d', ...
		sum(Ebet.Run==1),sum(Ebet.Run==2) );
end


%% Get date and time from the eprime and DICOM to verify eprime/fmri match
if isempty(fmri_dcm)
	
	warning('No fMRI DICOM provided - skipping eprime date/time check')
	
else
	
	eprime_date = unique(Efull.SessionDate(cellfun(@(x) ~isempty(x),Efull.SessionDate)));
	if numel(eprime_date)==0
		error('Failed to find SessionDate in eprime csv')
	elseif numel(eprime_date)>1
		error('Found multiple SessionDate in eprime csv')
	end
	eprime_time = unique(Efull.SessionTime(cellfun(@(x) ~isempty(x),Efull.SessionTime)));
	if numel(eprime_time)==0
		error('Failed to find SessionTime in eprime csv')
	elseif numel(eprime_time)>1
		if renumberflag==0
			error('Found multiple SessionTime in eprime csv')
		else
			warning('Multiple SessionTime in eprime csv (expected with renumbering)')
		end
	end
	eprime_datetime = datetime([eprime_date{1} ' ' eprime_time{1}], ...
		'InputFormat','MM-dd-yyyy HH:mm:ss');
	
	dcm = dicominfo(fmri_dcm);
	dcm_datetime = datetime([dcm.ContentDate dcm.ContentTime], ...
		'InputFormat','yyyyMMddHHmmss.SS');
	
	fprintf('Date and time for\n  Eprime: %s\n   DICOM: %s\n', ...
		eprime_datetime, dcm_datetime);
	
	if minutes(dcm_datetime - eprime_datetime) < 0
		if timeoverride==0
			error('FMRI acquisition began before Eprime')
		else
			warning('FMRI acquisition began before Eprime')
		end
	elseif minutes(dcm_datetime - eprime_datetime) > 60
		if timeoverride==0
			error('FMRI acquisition began more than an hour after Eprime')
		else
			warning('FMRI acquisition began more than an hour after Eprime')
		end
	elseif minutes(dcm_datetime - eprime_datetime) > 10
		warning('FMRI acquisition began more than 10 minutes after Eprime')
	end
	
end


%% fMRI timing offsets
% Get our fMRI timing offsets from MainTask entries
Emain = Efull(strcmp(Efull.Procedure,'MainTask'),:);
offsets = sort(Emain.WaitForScanner_OffsetTime);

for r = [1 2]
	Ebet.Offset_fMRI(Ebet.Run==r) = offsets(r);
	Ebet.T1_TrialStart_fMRIsec(Ebet.Run==r) = ...
		(Ebet.T1_TrialStart(Ebet.Run==r) - offsets(r)) / 1000;
	Ebet.T2b_CardFlipOnset_fMRIsec(Ebet.Run==r) = ...
		(Ebet.T2b_CardFlipOnset(Ebet.Run==r) - offsets(r)) / 1000;
	Ebet.T3_FeedbackOnset_fMRIsec(Ebet.Run==r) = ...
		(Ebet.T3_FeedbackOnset(Ebet.Run==r) - offsets(r)) / 1000;
	fprintf('Run %d first TrialStart: %0.2f sec\n', ...
		r,min(Ebet.T1_TrialStart_fMRIsec(Ebet.Run==r)));
end


%% Drop non-response trials temporarily to facilitate some computations
keeps = Ebet.NoResponse==0;
Ebet.TrialType(~keeps) = {'NoResponse'};
origE = Ebet;
Ebet = Ebet(keeps,:);


%% Loss types
Ebet.ProbabilisticLoss = strcmp(Ebet.Outcome,'Lose') & ...
	ismember(Ebet.ChosenProb,{'Deck80','Deck90'});
Ebet.SubOptimalDeckLoss = strcmp(Ebet.Outcome,'Lose') & ...
	ismember(Ebet.ChosenProb,{'Deck10','Deck20','Deck40','Deck50'});


%% Switch/stay
% The trial AFTER the win where they gave the switched response is the
% win-switch trial.
%
% We need to account for the breaks between runs - don't count across runs
for r = [1 2]
	inds = find(Ebet.Run==r);
	
	Ebet.TrialType{inds(1)} = 'InitialTrial';
	
	for h = 2:length(inds)
		if strcmp(Ebet.ChosenColor{inds(h)},Ebet.ChosenColor{inds(h)-1})
			Ebet.Switch{inds(h)} = 'Stay';
		else
			Ebet.Switch{inds(h)} = 'Switch';
		end
	end
	
	for h = 2:length(inds)
		if strcmp(Ebet.Outcome{inds(h)-1},'Win') & strcmp(Ebet.Switch{inds(h)},'Switch')
			Ebet.WinSwitch{inds(h)} = 'WinSwitch';
			Ebet.TrialType{inds(h)} = 'WinSwitch';
		end
		if strcmp(Ebet.Outcome{inds(h)-1},'Win') & strcmp(Ebet.Switch{inds(h)},'Stay')
			Ebet.WinStay{inds(h)} = 'WinStay';
			Ebet.TrialType{inds(h)} = 'WinStay';
		end
		if strcmp(Ebet.Outcome{inds(h)-1},'Lose') & strcmp(Ebet.Switch{inds(h)},'Switch')
			Ebet.LoseSwitch{inds(h)} = 'LoseSwitch';
			Ebet.TrialType{inds(h)} = 'LoseSwitch';
		end
		if strcmp(Ebet.Outcome{inds(h)-1},'Lose') & strcmp(Ebet.Switch{inds(h)},'Stay')
			Ebet.LoseStay{inds(h)} = 'LoseStay';
			Ebet.TrialType{inds(h)} = 'LoseStay';
		end
	end
	
end


%% Compute summaries per run, ignoring non-response trials
summary = table();
for r = [1 2]
	inds = Ebet.Run==r;
	
	summary.(['Run' num2str(r) '_AvgRT']) = ...
		mean(Ebet.RT(inds));
	
	summary.(['Run' num2str(r) '_EarnedOverall']) = ...
		Ebet.EarnedOverall(find(inds,1,'last'));
	
	summary.(['Run' num2str(r) '_Reversals']) = ...
		sum(Ebet.RuleChange(inds));
	
	summary.(['Run' num2str(r) '_WinStay']) = ...
		sum(strcmp(Ebet.TrialType(inds),'WinStay'));
	summary.(['Run' num2str(r) '_WinSwitch']) = ...
		sum(strcmp(Ebet.TrialType(inds),'WinSwitch'));
	summary.(['Run' num2str(r) '_LoseStay']) = ...
		sum(strcmp(Ebet.TrialType(inds),'LoseStay'));
	summary.(['Run' num2str(r) '_LoseSwitch']) = ...
		sum(strcmp(Ebet.TrialType(inds),'LoseSwitch'));
	
	summary.(['Run' num2str(r) '_WinStayPct']) = ...
		100 * summary.(['Run' num2str(r) '_WinStay']) / ...
		(summary.(['Run' num2str(r) '_WinStay']) + ...
		summary.(['Run' num2str(r) '_WinSwitch']) );
	
	summary.(['Run' num2str(r) '_WinSwitchPct']) = ...
		100 * summary.(['Run' num2str(r) '_WinSwitch']) / ...
		(summary.(['Run' num2str(r) '_WinStay']) + ...
		summary.(['Run' num2str(r) '_WinSwitch']) );
	
	summary.(['Run' num2str(r) '_LoseStayPct']) = ...
		100 * summary.(['Run' num2str(r) '_LoseStay']) / ...
		(summary.(['Run' num2str(r) '_LoseStay']) + ...
		summary.(['Run' num2str(r) '_LoseSwitch']) );
	
	summary.(['Run' num2str(r) '_LoseSwitchPct']) = ...
		100 * summary.(['Run' num2str(r) '_LoseSwitch']) / ...
		(summary.(['Run' num2str(r) '_LoseStay']) + ...
		summary.(['Run' num2str(r) '_LoseSwitch']) );
	
	summary.(['Run' num2str(r) '_ProbabilisticLoss']) = ...
		sum(Ebet.ProbabilisticLoss(inds));
	summary.(['Run' num2str(r) '_SubOptimalDeckLoss']) = ...
		sum(Ebet.SubOptimalDeckLoss(inds));
	
	% But for counting non-response trials we have to look at the original
	% full dataset
	summary.(['Run' num2str(r) '_NonResponses']) = ...
		sum(strcmp(origE.TrialType(origE.Run==r),'NoResponse'));
	
end

% Save
summary_csv = fullfile(out_dir,'eprime_summary.csv');
writetable(summary,summary_csv);


%% Restore non-response trials
Ebet = [Ebet; origE(~keeps,:)];
Ebet = sortrows(Ebet,'Trial');


%% Save trial-by-trial data
if renumoverride == 1
	% fMRI trial times are wrong if we renumbered, so exclude them from the
	% output so later steps will fail if they try to use them
	warning('FMRI trial times excluded from output due to trial renumbering')
	report = Ebet(:,{ ...
		'Run','Play_Sample','TrialType', 'RT', ...
		'Switch', ...
		'WinSwitch','WinStay','LoseSwitch','LoseStay',...
		'ChosenColor','ChosenProb', ...
		'WinningDeck','Outcome','ProbabilisticLoss','SubOptimalDeckLoss', ...
		'Offset_fMRI','T1_TrialStart', ...
		'T2b_CardFlipOnset', ...
		'T3_FeedbackOnset', ...
		});
else
	report = Ebet(:,{ ...
		'Run','Play_Sample','TrialType', 'RT', ...
		'Switch', ...
		'WinSwitch','WinStay','LoseSwitch','LoseStay',...
		'ChosenColor','ChosenProb', ...
		'WinningDeck','Outcome','ProbabilisticLoss','SubOptimalDeckLoss', ...
		'Offset_fMRI','T1_TrialStart','T1_TrialStart_fMRIsec', ...
		'T2b_CardFlipOnset','T2b_CardFlipOnset_fMRIsec', ...
		'T3_FeedbackOnset','T3_FeedbackOnset_fMRIsec' ...
		});
end
report_csv = fullfile(out_dir,'eprime_report.csv');
writetable(report,report_csv);



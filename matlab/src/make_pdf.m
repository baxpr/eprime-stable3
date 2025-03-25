function make_pdf(trial_csv,summary_csv,out_dir)

trial = readtable(trial_csv);
summary = readtable(summary_csv);

% Figure out screen size so the figure will fit
ss = get(0,'screensize');
ssw = ss(3);
ssh = ss(4);
ratio = 8.5/11;
if ssw/ssh >= ratio
	dh = ssh;
	dw = ssh * ratio;
else
	dw = ssw;
	dh = ssw / ratio;
end

% Create figure
pdf_figure = openfig('report.fig','new');
set(pdf_figure,'Tag','hgf_report');
set(pdf_figure,'Units','pixels','Position',[0 0 dw dh]);
figH = guihandles(pdf_figure);

% Parameter estimates
pstr = sprintf( ...
	[ ...
	'run12_mu_0_2:  %8.4f\n' ...
	'run12_mu_0_3:  %8.4f\n' ...
	'run12_kappa_2: %8.4f\n' ...
	'run12_omega_2: %8.4f\n' ...
	'run12_omega_3: %8.4f' ...
	], ...
	summary.run12_mu_0_2, ...
	summary.run12_mu_0_3, ...
	summary.run12_kappa_2, ...
	summary.run12_omega_2, ...
	summary.run12_omega_3 ...
	);
disp(pstr)
set(figH.params_text, 'String', pstr)

% GUIDE wouldn't save these settings for some reason
set(figH.params_text, 'HorizontalAlignment', 'Left')
set(figH.params_text, 'FontName', 'FixedWidth')
set(figH.params_text, 'FontUnits', 'normalized')
set(figH.params_text, 'FontSize', 0.07)
set(figH.titletext, 'FontUnits', 'normalized')
set(figH.titletext, 'FontSize', 0.7)

% Trajectory plots
axes(figH.ax1)
plot(trial.traj_mu_31)
ylabel('mu(3,1)')
title('Trajectories')
set(gca,'XTick',[])

axes(figH.ax2)
plot([trial.traj_epsi_2 trial.traj_epsi_3])
xlabel('Trial')
ylabel('epsilon')
legend({'epsilon(2)','epsilon(3)'})


% Print to PDF
print(gcf,'-dpdf',fullfile(out_dir,'report.pdf'))
close(gcf);


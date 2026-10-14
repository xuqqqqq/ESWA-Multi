function outputs = run_old_v2_combined_ablation(repeatFilter)
% Run the old critical_damage_v2 solver as a 2x2 module ablation.
if nargin < 1 || isempty(repeatFilter)
    repeatFilter = 1:10;
end

profiles = {'base_hga','damage_critical_only','period_relocate_only','damage_period_coupled'};
outputs = runAblationStudy('paper_lite', {}, repeatFilter, profiles);
end

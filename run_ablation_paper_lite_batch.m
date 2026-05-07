try
    outputs = runAblationStudy('paper_lite');
    save(fullfile('results', 'ablation_paper_lite_latest_outputs.mat'), 'outputs');

    fid = fopen(fullfile('results', 'ablation_paper_lite_done.txt'), 'w');
    fprintf(fid, 'done %s\n', datestr(now));
    fclose(fid);
catch ME
    fid = fopen(fullfile('results', 'ablation_paper_lite_error.txt'), 'w');
    fprintf(fid, '%s', getReport(ME, 'extended'));
    fclose(fid);
    exit(1);
end

exit(0);

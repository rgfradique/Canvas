function average_boxdata(outputfolder,samples,samp_labels)
%average_boxdata(outputfolder,sample names,sample labels)
%average_boxdata takes a folder containing the outputs from the
%Monet_single analysis, a list of sample names and sample labels, and
%outputs a descriptive csv for each file, as well as the aggregated
%analysis of all FOVs for the each sample


%{
% Version 1.0
% © Ricardo Fradique, Erika Causa 2023 (rgf34@cam.ac.uk) 
% 
% Canvas.m is licensed under a Creative Commons 
% Attribution-NonCommercial-NoDerivatives 4.0 International License.
% 
% Original work
%
%}
    ex_samples = string(samp_labels);
    accum_medfreq = [];
    accum_medfreq_tags = [];
    accum_coverage_perc = [];
    accum_coverage_perc_tags = [];
    accum_freqs = [];
    accum_freqs_tags = [];
    accum_coverage = [];
    accum_coverage_tags = [];
    accum_75p = [];
    accum_25p = [];
    accum_75p_tags = [];
    accum_25p_tags = [];

    for s = 1:length(samples)
        repeats_files = dir(fullfile(outputfolder,strcat("*",samples{s},"*","-data.mat"))); %%get all the repeats for that sample
        if isempty(repeats_files)
            ex_samples(find(ex_samples == samp_labels{s})) = [];
            continue;
        else
            csv_output = ["Filename", "Coverage %", "Median freq (Hz)", "25p", "75p"];
            for f = 1:size(repeats_files,1)
                file_path = fullfile(repeats_files(f).folder,repeats_files(f).name);
                load(file_path,'bg_map','fmap','frequencies');
                

                fmap_linear = reshape(fmap,[],1)';
                fmap_linear = fmap_linear(~isnan(fmap_linear));
                median_freq = median(fmap_linear,'omitnan');
                p25 = prctile(fmap_linear,25);
                p75 = prctile(fmap_linear,75);
                if isnan(median_freq)
                    median_freq = 0;
                    p25 = 0;
                    p75 = 0;
                end

                coverage_count = sum(~bg_map,'all');
                cov_perc = gather((coverage_count / (size(bg_map,1)*size(bg_map,2))) * 100);

                lineout = [string(repeats_files(f).name),gather(cov_perc),gather(median_freq),gather(p25),gather(p75)];
                csv_output = [csv_output; lineout];

                %% Sample data
                accum_coverage = [accum_coverage, coverage_count];
                accum_coverage_tags = [accum_coverage_tags, repmat(samp_labels(s),1,size(coverage_count,2))];


                accum_freqs = [accum_freqs,fmap_linear];
                accum_freqs_tags = [accum_freqs_tags, repmat(samp_labels(s),1,size(fmap_linear,2))];  

                accum_medfreq = [accum_medfreq, median_freq];
                accum_medfreq_tags = [accum_medfreq_tags, repmat(samp_labels(s),1,size(median_freq,2))];
                accum_coverage_perc = [accum_coverage_perc, cov_perc];
                accum_coverage_perc_tags = [accum_coverage_perc_tags, repmat(samp_labels(s),1,size(cov_perc,2))];
               
            end
            writematrix(csv_output,fullfile(outputfolder,strcat(samp_labels(s),".csv")));
        end
    end
    coverage_plot = figure;
    boxplot(accum_coverage_perc, accum_coverage_perc_tags);
    ylabel("% Covered")
    xtickangle(45)
    saveas(coverage_plot,fullfile(outputfolder,"coverage_distributions.png"));
    frequency_plot = figure;
    boxplot(gather(accum_medfreq), accum_medfreq_tags);
    ylabel("Frequency (Hz)")
    xtickangle(45)
    saveas(frequency_plot,fullfile(outputfolder,"frequency_distributions.png"));
    
    scatter_cbf = [];
    scatter_cov = [];
    scatter_tags = [];
    csv_output = ["Filename", "Coverage %", "Median freq (Hz)", "25p", "75p"];
    for tag = 1:length(ex_samples)
        sel_freqs = accum_freqs(accum_freqs_tags == ex_samples(tag));
        median_freq = median(sel_freqs,'omitnan');
        p25 = prctile(sel_freqs,25);
        p75 = prctile(sel_freqs,75);
        if isnan(median_freq)
            median_freq = 0;
            p25 = 0;
            p75 = 0;
        end
        
        total_coverage_perc = round((sum(accum_coverage(accum_coverage_tags == ex_samples(tag))) / (size(bg_map,1)*size(bg_map,2)* sum(accum_coverage_tags == ex_samples(tag)))) * 100);
        scatter_cbf = [scatter_cbf, median_freq];
        scatter_cov = [scatter_cov, total_coverage_perc];
        scatter_tags = [scatter_tags, ex_samples(tag)];

        csv_output = [csv_output; string(ex_samples(tag)),gather(total_coverage_perc),gather(median_freq),gather(p25),gather(p75)];
    end
    markers = "o+*.x_|^v><";
    scatter_plot=figure;
    gscatter(scatter_cbf, scatter_cov, categorical(scatter_tags),turbo(length(scatter_cbf)),markers);
    legend('Location','northeastoutside')
    xlabel("CBF");
    ylabel("Coverage %");
    saveas(scatter_plot,fullfile(outputfolder,"scatter_plot.png"))
    writematrix(csv_output,fullfile(outputfolder,"Aggregated.csv"));

end
            
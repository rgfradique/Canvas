function canvas_cli(config_file)
addpath(genpath('/home/rgf34/net/cicutagroup/rgf34/Code'));
savepath;

if exist(config_file) == 2
    file = fileread(config_file);
    data = jsondecode(file);
    data_folder = data{1};
    output_folder = data{2};
    label_list = data{3};
    tags_list = data{4};
    files_to_run = [];

    if isfolder(data_folder)
        filelist = dir(fullfile(data_folder,'/*.movie'));
        filetable = arrayfun(@(i)filelist(i).name,(1:numel(filelist)),'UniformOutput',0);
        files_runtable = [];

        llabel_list = split(label_list,",");
        ltags_list = split(tags_list,",");

        if (ltags_list(1)=="" && llabel_list(1)=="")
            app.Files_to_run = filelist;
        else
            if (length(ltags_list) ~= length(llabel_list) || ltags_list(1)=="" || llabel_list(1)=="")
                files_to_run = [];
            else
                for f=1:length(filetable)
                    counter = 0;
                    for t=1:length(ltags_list)
                        if contains(filetable(f),ltags_list(t))
                            if counter == 0
                                counter = 1;
                            else
                                disp("Error: Multiple tags detected");
                                counter = 2;
                            end
                        end
                    end
                    files_runtable = [files_runtable, counter];
                end
            end
            files_to_run = filelist(files_runtable == 1);
        end
    end


    run_first = 0;
    if exist(output_folder) == 0
        mkdir(output_folder)
    end
    timeelapsed = zeros(numel(files_to_run),1);
    startfrom = 1;
    stopat = numel(files_to_run);
    failed_list = [];
    set(0,'DefaultFigureVisible','off');
    try
        for i = startfrom:stopat
            tic
            if exist(fullfile(output_folder,strcat(files_to_run(i).name,"-data.mat"))) == 0
                if (i==1 || run_first == 0)
                    cur_path = fullfile(files_to_run(i).folder,files_to_run(i).name);
                    [bf_fs, fps] = load_movie(cur_path);
                    run_first = 1;
                else
                    [bf_fs, fps] = fetchOutputs(next_fs);
                end
                if i < stopat
                    next_path = fullfile(files_to_run(i+1).folder,files_to_run(i+1).name);
                    next_fs = parfeval(backgroundPool,@load_movie,2,next_path);
                end
                Monet_single(bf_fs,fps,files_to_run(i).name,output_folder);
            end
            timeelapsed(i) = toc;
     
            if i>5
                timetogo = mean(timeelapsed((i-4):i)) * (stopat-i);
            else
                timetogo = mean(timeelapsed(startfrom:i)) * (stopat-i);
            end
            cprintf('*[1 .3 0]',['\ntime remaning approx ',num2str(timetogo/60),' minutes\n']);
        end

        if (label_list~="" && tags_list~="")
            disp("Starting aggregation")
            average_boxdata(output_folder,split(tags_list,","),split(label_list,","));
        end
    catch err
        disp('Script Failed');
        disp(err.message);
        failed_list = [failed_list, files_to_run(i).name]
        disp(failed_list)
    end
    close all;

end
end
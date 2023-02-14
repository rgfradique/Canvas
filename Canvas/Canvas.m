classdef Canvas < matlab.apps.AppBase
%Canvas allows the user to select an input data folder, output data
%folder, files identification and sample name strings, and
%runs instances of the Monet_single on all files selected. When done, it 
%aggregates all results by sample tag/name.
%
%   Canvas opens a GUI asking the user to input the
%   variables needed
%
%   canvas_cli(config_file_path) starts the analysis without the GUI
%   All folders need to be read/writeable


%{
% Version 1.0
% © Ricardo Fradique,Erika Causa 2023 (rgf34@cam.ac.uk) 
% 
% Canvas.m is licensed under a Creative Commons 
% Attribution-NonCommercial-NoDerivatives 4.0 International License.s
% 
% Original work
%
%}

    % Properties that correspond to app components
    properties (Access = public)
        Main                        matlab.ui.Figure
        Layout                      matlab.ui.container.GridLayout
        time                        matlab.ui.control.EditField
        EditFieldLabel              matlab.ui.control.Label
        output_folder               matlab.ui.control.EditField
        OutputfolderEditFieldLabel  matlab.ui.control.Label
        files_button                matlab.ui.control.Button
        label_list                  matlab.ui.control.EditField
        CommaseparatedlabelEditFieldLabel  matlab.ui.control.Label
        files_table                 matlab.ui.control.Table
        tags_list                   matlab.ui.control.EditField
        CommaseparatednameEditField_2Label  matlab.ui.control.Label
        files_path                  matlab.ui.control.EditField
        DatafolderEditFieldLabel    matlab.ui.control.Label
        run_button                  matlab.ui.control.Button
    end


    properties (Access = public)
        Filepath; % Filepath for the data folder
        Output_folder; %Filepath for output data
        Filelist; %List of files id'd in the folder
        Files_to_run; %List of files to actually run
    end

    methods (Access = private)
        function load_config(app,folder) % Loads a sample_settings.cfg file with sample information and updates the UI
            if exist(fullfile(folder,"sample_settings.cfg")) == 2
                file = fileread(fullfile(folder,"sample_settings.cfg"));
                data = jsondecode(file);
                msgbox(strcat("Loaded config from: ",folder));
                app.label_list.Value = data{3};
                app.tags_list.Value = data{4};
                update_list(app);
            end
        end
        
        function save_config(app) % Saves all sample information into a sample_settings.cfg file in the output folder
            if exist(fullfile(app.Output_folder,"sample_settings.cfg")) == 0
                settings = {app.Filepath; app.Output_folder; app.label_list.Value; app.tags_list.Value};
                js_save = jsonencode(settings);
                fid = fopen(fullfile(app.Output_folder,"sample_settings.cfg"),'w');
                fprintf(fid, js_save);
                fclose(fid);
            end
        end
        
        function [] = lock_unlock(app, toggle_off) % Lock the interface while the analysis is running
            if toggle_off
                set(app.run_button, 'Enable', 'off');
                drawnow;
            else
                set(app.run_button, 'Enable', 'on');
                drawnow;
            end
        end
        
        function [] = update_list(app) % Update file list with all valid file names, current sample tags and corresponding sample names
            if isfolder(app.Filepath)
                app.Filelist = [dir(fullfile(app.Filepath,'*.movie'));dir(fullfile(app.Filepath,'*.mp4'))];
                filetable = arrayfun(@(i)app.Filelist(i).name,(1:numel(app.Filelist)),'UniformOutput',0);
                label_table = [];
                files_runtable = [];
                ltags_list = split(app.tags_list.Value,",");
                llabel_list = split(app.label_list.Value,",");

                if (ltags_list(1)=="" && llabel_list(1)=="")
                    app.tags_list.BackgroundColor = 'w';
                    app.label_list.BackgroundColor = 'w';
                    label_table = repmat("Empty, include all",size(filetable));
                    app.Files_to_run = app.Filelist;
                    lock_unlock(app, 0);
                else
                    if (length(ltags_list) ~= length(llabel_list) || ltags_list(1)=="" || llabel_list(1)=="")
                        app.tags_list.BackgroundColor = 'r';
                        app.label_list.BackgroundColor = 'r';
                        label_table = repmat("Mismatch",size(filetable));
                        app.Files_to_run = [];
                        lock_unlock(app, 1);
                    else
                        lock_unlock(app, 0);
                        app.tags_list.BackgroundColor = 'w';
                        app.label_list.BackgroundColor = 'w';
                        for f=1:length(filetable)
                            counter = 0;
                            tag = "No tag, not included";
                            for t=1:length(ltags_list)
                                if contains(filetable(f),ltags_list(t))
                                    if counter == 0
                                        counter = 1;
                                        tag = llabel_list(t);
                                    else
                                        tag = "Multiple tags!";
                                        counter = 2;
                                    end
                                end
                            end
                            label_table = [label_table, tag];
                            files_runtable = [files_runtable, counter];
                        end
                    end
                    app.Files_to_run = app.Filelist(files_runtable == 1);
                end

                filetable = [filetable', label_table'];
                app.files_table.Data=table(filetable);
                return
            end
        end


    end


    % Callbacks that handle component events
    methods (Access = private)

        % On startup, pre-populate fields with current dir and look for config file in the default output folder
        function startup(app)
            app.Filepath = pwd;
            app.files_path.Value = app.Filepath;
            get_files(app);
            load_config(app,app.Output_folder);
        end
        
        function get_folders(app, event)
            app.Filepath = app.files_path.Value;
            app.Output_folder = app.output_folder.Value;
        end

        % Open file manager UI
        function files_buttonButtonPushed(app, event)
            app.files_path.Value = uigetdir;
            app.Filepath = app.files_path.Value;
            app.Output_folder = strcat(app.Filepath,'_Analysis');
            app.output_folder.Value = app.Output_folder;
            get_files(app);
            load_config(app,app.Output_folder);
        end

        % Run the analysis; Depends on backgroundPool to pre-load next file on background
        function run_analysis(app, event)
            run_first = 0;
            if exist(app.Output_folder) == 0
                mkdir(app.Output_folder)
            end
            save_config(app);
            lock_unlock(app, 1);
            get_folders(app);
            timeelapsed = zeros(numel(app.Files_to_run),1);
            startfrom = 1;
            stopat = numel(app.Files_to_run);
            failed_list = [];
            set(0,'DefaultFigureVisible','off');
            try
                for i = startfrom:stopat
                    tic
                    if exist(fullfile(app.Output_folder,strcat(app.Files_to_run(i).name,"-data.mat"))) == 0
                        if (i==1 || run_first == 0)
                            cur_path = fullfile(app.Files_to_run(i).folder,app.Files_to_run(i).name);
                            [bf_fs, fps] = load_movie(cur_path);
                            run_first = 1;
                        else
                            [bf_fs, fps] = fetchOutputs(next_fs);
                        end
                        if i < stopat
                            next_path = fullfile(app.Files_to_run(i+1).folder,app.Files_to_run(i+1).name);
                            next_fs = parfeval(backgroundPool,@load_movie,2,next_path);
                        end
                        Monet_single(bf_fs,fps,app.Files_to_run(i).name,app.Output_folder);
                    end
                    timeelapsed(i) = toc;
                    if i>5
                        timetogo = mean(timeelapsed((i-4):i)) * (stopat-i);
                    else
                        timetogo = mean(timeelapsed(startfrom:i)) * (stopat-i);
                    end
                    cprintf('*[1 .3 0]',['\ntime remaning approx ',num2str(timetogo/60),' minutes\n']);
                    app.time.Value = strcat(num2str(timetogo/60)," minutes to go; ", string(i),"/",string(stopat));
                    
                end
                
                if (app.label_list.Value~="" && app.tags_list.Value~="")
                    disp("Starting aggregation")
                    average_boxdata(app.Output_folder,split(app.tags_list.Value,","),split(app.label_list.Value,","));
                end
            catch err
                disp('Script Failed');
                disp(err.message);
                failed_list = [failed_list, app.Files_to_run(i).name]
                disp(failed_list)
            end            
            close all;
            set(0,'DefaultFigureVisible','on')
            app.time.Value = "Done!"
            lock_unlock(app, 0);
        end

        % Value changed function: files_path, label_list, tags_list
        function get_files_config_output(app,event)
            get_files(app, event);
            load_config(app,app.Output_folder);
        end
        function get_files_config_input(app,event)
            load_config(app,app.Filepath);
            get_files(app, event);
        end
        
        function get_files(app, event)
            data_folder = app.Filepath;
            
            if ~isfolder(data_folder)
                app.files_path.BackgroundColor = 'r';
                return
            else
                app.files_path.BackgroundColor = 'w';
            end %if

            if strcmp(data_folder(end),'/') || strcmp(data_folder(end),'\')
                data_folder = data_folder(1:end-1);
                app.files_path.Value = data_folder;
            end

            % update analysis folder name
            if app.output_folder.Value == ""
                app.Output_folder = strcat(data_folder,'_Analysis');
                app.output_folder.Value = app.Output_folder;
            else
                app.Output_folder = app.output_folder.Value;
            end

            update_list(app);     
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            addpath(genpath(pwd));

            % Create Main and hide until all components are created
            app.Main = uifigure('Visible', 'off');
            app.Main.Position = [100 100 640 480];
            app.Main.Name = 'MATLAB App';

            % Create Layout
            app.Layout = uigridlayout(app.Main);
            app.Layout.ColumnWidth = {'1x', '1x', '1x', '0.5x'};
            app.Layout.RowHeight = {'1x', '1x', '1x', '1x', '1x', '1x', '1x', '1x'};

            % Create run_button
            app.run_button = uibutton(app.Layout, 'push');
            app.run_button.ButtonPushedFcn = createCallbackFcn(app, @run_analysis, true);
            app.run_button.Layout.Row = 8;
            app.run_button.Layout.Column = [1 2];
            app.run_button.Text = 'Run analysis';

            % Create DatafolderEditFieldLabel
            app.DatafolderEditFieldLabel = uilabel(app.Layout);
            app.DatafolderEditFieldLabel.HorizontalAlignment = 'right';
            app.DatafolderEditFieldLabel.Layout.Row = 1;
            app.DatafolderEditFieldLabel.Layout.Column = 1;
            app.DatafolderEditFieldLabel.Text = 'Data folder';

            % Create files_path
            app.files_path = uieditfield(app.Layout, 'text');
            app.files_path.ValueChangedFcn = createCallbackFcn(app, @get_files_config_input, true);
            app.files_path.Layout.Row = 1;
            app.files_path.Layout.Column = [2 3];

            % Create CommaseparatednameEditField_2Label
            app.CommaseparatednameEditField_2Label = uilabel(app.Layout);
            app.CommaseparatednameEditField_2Label.HorizontalAlignment = 'right';
            app.CommaseparatednameEditField_2Label.Layout.Row = 3;
            app.CommaseparatednameEditField_2Label.Layout.Column = 1;
            app.CommaseparatednameEditField_2Label.Text = 'Comma separated name';

            % Create tags_list
            app.tags_list = uieditfield(app.Layout, 'text');
            app.tags_list.ValueChangedFcn = createCallbackFcn(app, @get_files, true);
            app.tags_list.Layout.Row = 3;
            app.tags_list.Layout.Column = [2 4];

            % Create files_table
            app.files_table = uitable(app.Layout);
            app.files_table.ColumnName = {'Filename','Tag'};
            app.files_table.RowName = {};
            %app.files_table.Multiselect = 'off';
            app.files_table.Layout.Row = [5 7];
            app.files_table.Layout.Column = [1 4];

            % Create CommaseparatedlabelEditFieldLabel
            app.CommaseparatedlabelEditFieldLabel = uilabel(app.Layout);
            app.CommaseparatedlabelEditFieldLabel.HorizontalAlignment = 'right';
            app.CommaseparatedlabelEditFieldLabel.Layout.Row = 4;
            app.CommaseparatedlabelEditFieldLabel.Layout.Column = 1;
            app.CommaseparatedlabelEditFieldLabel.Text = 'Comma separated label';

            % Create label_list
            app.label_list = uieditfield(app.Layout, 'text');
            app.label_list.ValueChangedFcn = createCallbackFcn(app, @get_files, true);
            app.label_list.Layout.Row = 4;
            app.label_list.Layout.Column = [2 4];

            % Create files_button
            app.files_button = uibutton(app.Layout, 'push');
            app.files_button.ButtonPushedFcn = createCallbackFcn(app, @files_buttonButtonPushed, true);
            app.files_button.Layout.Row = 1;
            app.files_button.Layout.Column = 4;
            app.files_button.Text = '...';

            % Create OutputfolderEditFieldLabel
            app.OutputfolderEditFieldLabel = uilabel(app.Layout);
            app.OutputfolderEditFieldLabel.HorizontalAlignment = 'right';
            app.OutputfolderEditFieldLabel.Layout.Row = 2;
            app.OutputfolderEditFieldLabel.Layout.Column = 1;
            app.OutputfolderEditFieldLabel.Text = 'Output folder';

            % Create output_folder
            app.output_folder = uieditfield(app.Layout, 'text');
            app.output_folder.ValueChangedFcn = createCallbackFcn(app, @get_files_config_output, true);
            app.output_folder.Layout.Row = 2;
            app.output_folder.Layout.Column = [2 4];

            % Create EditFieldLabel
            app.EditFieldLabel = uilabel(app.Layout);
            app.EditFieldLabel.HorizontalAlignment = 'right';
            app.EditFieldLabel.Layout.Row = 8;
            app.EditFieldLabel.Layout.Column = 3;
            app.EditFieldLabel.Text = 'Edit Field';

            % Create time
            app.time = uieditfield(app.Layout, 'text');
            app.time.Layout.Row = 8;
            app.time.Layout.Column = [3 4];

            % Show the figure after all components are created
            app.Main.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = Canvas

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.Main)

            % Execute the startup function
            runStartupFcn(app, @startup)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.Main)
        end
    end
end
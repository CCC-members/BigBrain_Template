function EEGs = import_eeg_format(subID, selected_data_set, base_path)

data_type    = selected_data_set.preprocessed_data.format;
if(~isequal(selected_data_set.preprocessed_data.channel_label_file,"none"))
    user_labels = jsondecode(fileread(selected_data_set.preprocessed_data.channel_label_file));    
end
if(selected_data_set.preprocessed_data.clean_data.run)    
    if(isequal(lower(selected_data_set.preprocessed_data.clean_data.toolbox),'eeglab'))
        toolbox_path    = selected_data_set.preprocessed_data.clean_data.toolbox_path;
        max_freq        = selected_data_set.preprocessed_data.clean_data.max_freq;            
        select_events   = selected_data_set.preprocessed_data.clean_data.select_events;
        %         save_path    = fullfile(selected_data_set.report_output_path,'Reports',selected_data_set.protocol_name,subject_info.name,'EEGLab_preproc');
        if(exist('user_labels','var'))
            EEGs      = eeglab_preproc(subID, base_path, data_type, toolbox_path, 'verbosity', true, 'max_freq', max_freq,...
                'labels', user_labels, 'select_events', select_events);
        else
            EEGs      = eeglab_preproc(subID, base_path, data_type, toolbox_path, 'verbosity', true, 'max_freq', max_freq,...
                'read_segments', 'select_events', select_events);
        end
        for i=1:length(EEGs)
            EEGs(i).labels   = {EEGs(i).chanlocs(:).labels};
        end
    end
else
    EEG         = struct;
    EEG.subID   = subID;
    EEG.setname = subID;
    switch data_type
        case 'edf'
            [hdr, data]     = edfread(base_path);
             EEG.data    = data;
             EEG.labels  = strrep(hdr.label,'REF','');
             EEG.srate   = hdr.samples(1);
        case 'plg'
            [pat_info, inf_info, plg_info, mrk_info, win_info, cdc_info, states_name] = plg2matlab(base_path);
            % creating output structure
            data            = plg_info.data;            
            hdr.pat_info    = pat_info;
            hdr.inf_info    = inf_info;
            hdr.mrk_info    = mrk_info;
            hdr.win_info    = win_info;
            hdr.cdc_info    = cdc_info;
            hdr.states_name = states_name;
            hdr.label       = inf_info.PLGMontage;
            EEG.data    = data;
            EEG.labels  = strrep(hdr.label,'REF','');
            EEG.srate   = hdr.samples(1);
        case 'txt'
            load('templates/EEG_template_58Ch.mat');
            [filepath,filename,~]   = fileparts(base_path);
            EEG.filename            = filename;
            EEG.filepath            = filepath;
            EEG.subject             = subID;
            data                    = readmatrix(base_path);
            data                    = data';
            EEG.data                = data;
            EEG.nbchan              = length(EEG.chanlocs);
            EEG.pnts                = size(data,2);
            EEG.srate               = 200;
            EEG.min                 = 0;
            EEG.max                 = EEG.xmin+(EEG.pnts-1)*(1/EEG.srate);
            EEG.times               = (0:EEG.pnts-1)/EEG.srate.*1000;
            EEG.subID               = subID;
            EEG.setname             = subID;
    end   
    if(exist('user_labels','var'))
        disp ("-->> Cleanning EEG bad Channels by user labels");
        EEG         = remove_eeg_channels_by_labels(user_labels,EEG);
        EEG.labels  = {EEG.chanlocs(:).labels};
    end
    EEGs = EEG;
end
end
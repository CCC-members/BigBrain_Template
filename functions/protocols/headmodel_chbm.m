function [processed] = headmodel_chbm()
% TUTORIAL: Script that reproduces the results of the online tutorials.
%
%
% @=============================================================================
%
% Authors:
% - Ariosky Areces Gonzalez
% - Deirel Paz Linares


%%
%% Preparing selected protocol
%%
load('tools/mycolormap');

app_properties = jsondecode(fileread(strcat('app',filesep,'app_properties.json')));
selected_data_set = jsondecode(fileread(strcat('config_protocols',filesep,app_properties.selected_data_set.file_name)));

modality = selected_data_set.modality;

if(is_check_dataset_properties(selected_data_set))
    disp(strcat('-->> Data Source:  ', selected_data_set.hcp_data_path.base_path ));
    ProtocolName = selected_data_set.protocol_name;
    [base_path,name,ext] = fileparts(selected_data_set.hcp_data_path.base_path);
    subjects = dir(base_path);
    subjects(ismember( {subjects.name}, {'.', '..'})) = [];  %remove . and ..
    subjects_process_error = [];
    subjects_processed =[];
    Protocol_count = 0;
    for j=1:size(subjects,1)
        subject_name = subjects(j).name;
        subID = subject_name;
        if(~isequal(selected_data_set.sub_prefix,'none') && ~isempty(selected_data_set.sub_prefix))
            subID = strrep(subject_name,selected_data_set.sub_prefix,'');
        end
        
        disp(strcat('-->> Processing subject: ', subID));
        %%
        %% Preparing Subject files
        %%        
        [subject_environment, files_checked] = get_subject_files(selected_data_set,subID,'chbm',ProtocolName);        
        if(~files_checked)
            continue;
        end
        T1w_file            = subject_environment.T1w_file;
        L_surface_file      = subject_environment.L_surface_file;
        R_surface_file      = subject_environment.R_surface_file;
        Atlas_seg_location  = subject_environment.Atlas_seg_location;
        head_file           = subject_environment.head_file;
        outerskull_file     = subject_environment.outerskull_file;
        innerskull_file     = subject_environment.innerskull_file;
        subject_report_path = subject_environment.subject_report_path;
        report_name         = subject_environment.report_name;

        %%
        %%  Checking protocol
        %%
        if( mod(Protocol_count,selected_data_set.protocol_subjet_count) == 0  )
            ProtocolName_R = strcat(ProtocolName,'_',char(num2str(Protocol_count)));
            
            if(selected_data_set.protocol_reset)
                gui_brainstorm('DeleteProtocol',ProtocolName_R);
                bst_db_path = bst_get('BrainstormDbDir');
                if(isfolder(fullfile(bst_db_path,ProtocolName_R)))
                    protocol_folder = fullfile(bst_db_path,ProtocolName_R);
                    rmdir(protocol_folder, 's');
                end
                gui_brainstorm('CreateProtocol',ProtocolName_R ,selected_data_set.use_default_anatomy, selected_data_set.use_default_channel);
            else
                %                 gui_brainstorm('UpdateProtocolsList');
                iProtocol = bst_get('Protocol', ProtocolName_R);
                gui_brainstorm('SetCurrentProtocol', iProtocol);
                subjects = bst_get('ProtocolSubjects');
                if(j <= length(subjects.Subject))
                    db_delete_subjects( j );
                end
            end
        end
        
%         try
            %%
            %% Creating subject in Protocol
            %%
            db_add_subject(subID);
            
            %%
            %% Preparing eviroment
            %%
            % ===== GET DEFAULT =====
            % Get registered Brainstorm EEG defaults
            bstDefaults = bst_get('EegDefaults');
            nameGroup = selected_data_set.process_import_channel.group_layout_name;
            nameLayout = selected_data_set.process_import_channel.channel_layout_name;
            
            iGroup = find(strcmpi(nameGroup, {bstDefaults.name}));
            iLayout = strcmpi(nameLayout, {bstDefaults(iGroup).contents.name});
            ChannelFile = bstDefaults(iGroup).contents(iLayout).fullpath;
%             channel_layout= load(ChannelFile);
            
            %% reduce channel by preprocessed eeg or user labels
%             [ChannelFile] = reduce_channel_BY_prep_eeg_OR_user_labels(selected_data_set,channel_layout,ChannelFile,subID);
            
            %%
            %% ===== IMPORT ANATOMY =====
            %%
            % Start a new report
            bst_report('Start',['Protocol for subject:' , subID]);
            bst_report('Info',    '', [], ['Protocol for subject:' , subID]);
            
            %%
            %% Process: Import MRI
            %%
            sFiles = bst_process('CallProcess', 'process_import_mri', [], [], ...
                'subjectname', subID, ...
                'mrifile',     {T1w_file, 'ALL-MNI'});
            
            %%
            %% Quality control
            %%
            % Get subject definition
            sSubject = bst_get('Subject', subID);
           
            % Get MRI file and surface files            
            MriFile    = sSubject.Anatomy(sSubject.iAnatomy).FileName;
            hFigMri1 = view_mri_slices(MriFile, 'x', 20);
            bst_report('Snapshot',hFigMri1,MriFile,'MRI Axial view', [200,200,750,475]);
            savefig( hFigMri1,fullfile(subject_report_path,'MRI Axial view.fig'));
            close(hFigMri1);
            
            hFigMri2 = view_mri_slices(MriFile, 'y', 20);
            bst_report('Snapshot',hFigMri2,MriFile,'MRI Coronal view', [200,200,750,475]);
            savefig( hFigMri2,fullfile(subject_report_path,'MRI Coronal view.fig'));
            close(hFigMri2);
            
            hFigMri3 = view_mri_slices(MriFile, 'z', 20);
            bst_report('Snapshot',hFigMri3,MriFile,'MRI Sagital view', [200,200,750,475]);
            savefig( hFigMri3,fullfile(subject_report_path,'MRI Sagital view.fig'));
            close(hFigMri3);
            
            %%
            %% Process: Import surfaces
            %%
            nverthead = selected_data_set.process_import_surfaces.nverthead;
            nvertcortex = selected_data_set.process_import_surfaces.nvertcortex;
            nvertskull = selected_data_set.process_import_surfaces.nvertskull;
            
            sFiles = bst_process('CallProcess', 'script_process_import_surfaces', sFiles, [], ...
                'subjectname', subID, ...
                'headfile',    {head_file, 'MRI-MASK-MNI'}, ...
                'cortexfile1', {L_surface_file, 'GII-MNI'}, ...
                'cortexfile2', {R_surface_file, 'GII-MNI'}, ...                
                'innerfile',   {innerskull_file, 'MRI-MASK-MNI'}, ...
                'outerfile',   {outerskull_file, 'MRI-MASK-MNI'}, ...
                'nverthead',   nverthead, ...
                'nvertcortex', nvertcortex, ...
                'nvertskull',  nvertskull);
                        
            %%
            %% ===== IMPORT SURFACES 32K =====
            %%
            [sSubject, iSubject] = bst_get('Subject', subID);
            % Left pial
            [iLh, BstTessLhFile, nVertOrigL] = import_surfaces(iSubject, L_surface_file, 'GII-MNI', 0);
            BstTessLhFile = BstTessLhFile{1};
            % Right pial
            [iRh, BstTessRhFile, nVertOrigR] = import_surfaces(iSubject, R_surface_file, 'GII-MNI', 0);
            BstTessRhFile = BstTessRhFile{1};
            
            %%
            %% ===== MERGE SURFACES =====
            %%
            % Merge surfaces
            [TessFile32K, iSurface] = tess_concatenate({BstTessLhFile, BstTessRhFile}, sprintf('cortex_%dV', nVertOrigL + nVertOrigR), 'Cortex');
            % Delete original files
            file_delete(file_fullpath({BstTessLhFile, BstTessRhFile}), 1);
            % Compute missing fields
            in_tess_bst( TessFile32K, 1);
            % Reload subject
            db_reload_subjects(iSubject);
            % Set file type
            db_surface_type(TessFile32K, 'Cortex');
            % Set default cortex
            db_surface_default(iSubject, 'Cortex', 2);
            
            %%
            %% Quality control
            %%
            % Get subject definition and subject files
            sSubject       = bst_get('Subject', subID);
            MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
            CortexFile     = sSubject.Surface(sSubject.iCortex).FileName;
            InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
            OuterSkullFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
            ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
            
            %            
            hFigMriSurf = view_mri(MriFile, CortexFile);
            
            hFigMri4  = script_view_contactsheet( hFigMriSurf, 'volume', 'x','');
            bst_report('Snapshot',hFigMri4,MriFile,'Cortex - MRI registration Axial view', [200,200,750,475]);
            savefig( hFigMri4,fullfile(subject_report_path,'Cortex - MRI registration Axial view.fig'));
            close(hFigMri4);
            %
            hFigMri5  = script_view_contactsheet( hFigMriSurf, 'volume', 'y','');
            bst_report('Snapshot',hFigMri5,MriFile,'Cortex - MRI registration Coronal view', [200,200,750,475]);
            savefig( hFigMri5,fullfile(subject_report_path,'Cortex - MRI registration Coronal view.fig'));
            close(hFigMri5);
            %
            hFigMri6  = script_view_contactsheet( hFigMriSurf, 'volume', 'z','');
            bst_report('Snapshot',hFigMri6,MriFile,'Cortex - MRI registration Sagital view', [200,200,750,475]);
            savefig( hFigMri6,fullfile(subject_report_path,'Cortex - MRI registration Sagital view.fig'));
            % Closing figures
            close([hFigMri6,hFigMriSurf]);
            
            %
            hFigMri7 = view_mri(MriFile, ScalpFile);
            bst_report('Snapshot',hFigMri7,MriFile,'Scalp registration', [200,200,750,475]);
            savefig( hFigMri7,fullfile(subject_report_path,'Scalp registration.fig'));
            close(hFigMri7);
            %
            hFigMri8 = view_mri(MriFile, OuterSkullFile);
            bst_report('Snapshot',hFigMri8,MriFile,'Outer Skull - MRI registration', [200,200,750,475]);
            savefig( hFigMri8,fullfile(subject_report_path,'Outer Skull - MRI registration.fig'));
            close(hFigMri8);
            %
            hFigMri9 = view_mri(MriFile, InnerSkullFile);
            bst_report('Snapshot',hFigMri9,MriFile,'Inner Skull - MRI registration', [200,200,750,475]);
            savefig( hFigMri9,fullfile(subject_report_path,'Inner Skull - MRI registration.fig'));
            % Closing figures
            close(hFigMri9);
            
            %
            hFigSurf10 = view_surface(CortexFile);
            bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D top view', [200,200,750,475]);
            savefig( hFigSurf10,fullfile(subject_report_path,'Cortex mesh 3D view.fig'));
            % Bottom
            view(90,270)
            bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D bottom view', [200,200,750,475]);
            %Left
            view(1,180)
            bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D left hemisphere view', [200,200,750,475]);
            % Rigth
            view(0,360)
            bst_report('Snapshot',hFigSurf10,[],'Cortex mesh 3D right hemisphere view', [200,200,750,475]);
            
            % Closing figure
            close(hFigSurf10);
            
            %%
            %% Process: Generate BEM surfaces
            %%
            bst_process('CallProcess', 'process_generate_bem', [], [], ...
                'subjectname', subID, ...
                'nscalp',      3242, ...
                'nouter',      3242, ...
                'ninner',      3242, ...
                'thickness',   4);
            
            %%
            %% Get subject definition and subject files
            %%
            sSubject       = bst_get('Subject', subID);
            CortexFile     = sSubject.Surface(sSubject.iCortex).FileName;
            InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
            
            %%
            %% Forcing dipoles inside innerskull
            %%
            %             [iIS, BstTessISFile, nVertOrigR] = import_surfaces(iSubject, innerskull_file, 'MRI-MASK-MNI', 1);
            %             BstTessISFile = BstTessISFile{1};
            script_tess_force_envelope(CortexFile, InnerSkullFile);
            
            %%
            %% Get subject definition and subject files
            %%
            sSubject       = bst_get('Subject', subID);
            MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
            CortexFile     = sSubject.Surface(sSubject.iCortex).FileName;
            InnerSkullFile = sSubject.Surface(sSubject.iInnerSkull).FileName;
            OuterSkullFile = sSubject.Surface(sSubject.iOuterSkull).FileName;
            ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
            iCortex        = sSubject.iCortex;
            iAnatomy       = sSubject.iAnatomy;
            iInnerSkull    = sSubject.iInnerSkull;
            iOuterSkull    = sSubject.iOuterSkull;
            iScalp         = sSubject.iScalp;
            
            %%
            %% Quality control
            %%
            
            hFigSurf11 = script_view_surface(CortexFile, [], [], [],'top');
            hFigSurf11 = script_view_surface(InnerSkullFile, [], [], hFigSurf11);
            hFigSurf11 = script_view_surface(OuterSkullFile, [], [], hFigSurf11);
            hFigSurf11 = script_view_surface(ScalpFile, [], [], hFigSurf11);
            bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration top view', [200,200,750,475]);
            savefig( hFigSurf11,fullfile(subject_report_path,'BEM surfaces registration view.fig'));
            % Left
            view(1,180)
            bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration left view', [200,200,750,475]);
            % Right
            view(0,360)
            bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration right view', [200,200,750,475]);
            % Front
            view(90,360)
            bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration front view', [200,200,750,475]);
            % Back
            view(270,360)
            bst_report('Snapshot',hFigSurf11,[],'BEM surfaces registration back view', [200,200,750,475]);
            % Closing figure
            close(hFigSurf11);
            
            %%
            %% Process: Generate SPM canonical surfaces
            %%
            sFiles = bst_process('CallProcess', 'process_generate_canonical', sFiles, [], ...
                'subjectname', subID, ...
                'resolution',  2);  % 8196
            
            %%
            %% Quality control
            %%
            % Get subject definition and subject files
            sSubject       = bst_get('Subject', subID);
            ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
            
            %
            hFigMri15 = view_mri(MriFile, ScalpFile);
            bst_report('Snapshot',hFigMri15,[],'SPM Scalp Envelope - MRI registration', [200,200,750,475]);
            savefig( hFigMri15,fullfile(subject_report_path,'SPM Scalp Envelope - MRI registration.fig'));
            % Close figures
            close(hFigMri15);
            
            %%
            %% ===== ACCESS RECORDINGS =====
            %%
            FileFormat = 'BST';
            
            %%
            %% See Description for -->> import_channel(iStudies, ChannelFile, FileFormat, ChannelReplace,
            % ChannelAlign, isSave, isFixUnits, isApplyVox2ras)
            %%
            sSubject = bst_get('Subject', subID);            
            [sStudies, iStudy] = bst_get('StudyWithSubject', sSubject.FileName, 'intra_subject');            
            
            [Output, ChannelFile, FileFormat] = import_channel(iStudy, ChannelFile, FileFormat, 2, 2, 1, 1, 1);
            
            %%
            %% Process: Set BEM Surfaces
            %%
            [sSubject, iSubject] = bst_get('Subject', subID);
            db_surface_default(iSubject, 'Scalp', iScalp);
            db_surface_default(iSubject, 'OuterSkull', iOuterSkull);
            db_surface_default(iSubject, 'InnerSkull', iInnerSkull);
            db_surface_default(iSubject, 'Cortex', iCortex);
            
            %%
            %% Project electrodes on the scalp surface.
            %%
            % Get Protocol information
            ProtocolInfo = bst_get('ProtocolInfo');
            % Get subject directory
            [sSubject] = bst_get('Subject', subID);
            sStudy = bst_get('Study', iStudy);
            
            ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
            BSTScalpFile = bst_fullfile(ProtocolInfo.SUBJECTS, ScalpFile);
            head = load(BSTScalpFile);
            
            BSTChannelsFile = bst_fullfile(ProtocolInfo.STUDIES,sStudy.Channel.FileName);
            BSTChannels = load(BSTChannelsFile);
            channels = [BSTChannels.Channel.Loc];
            channels = channels';
            channels = channel_project_scalp(head.Vertices, channels);
            
            % Report projections in original structure
            for iChan = 1:length(channels)
                BSTChannels.Channel(iChan).Loc = channels(iChan,:)';
            end
            % Save modifications in channel file
            bst_save(file_fullpath(BSTChannelsFile), BSTChannels, 'v7');
            
            %%
            %% Quality control
            %%
            % View sources on MRI (3D orthogonal slices)
            [sSubject, iSubject] = bst_get('Subject', subID);
            
            MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
            
            hFigMri16      = script_view_mri_3d(MriFile, [], [], [], 'front');
            hFigMri16      = view_channels(ChannelFile, 'EEG', 1, 0, hFigMri16, 1);
            bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration front view', [200,200,750,475]);
            savefig( hFigMri16,fullfile(subject_report_path,'Sensor-MRI registration front view.fig'));
            %Left
            view(1,180)
            bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration left view', [200,200,750,475]);
            % Right
            view(0,360)
            bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration right view', [200,200,750,475]);
            % Back
            view(90,360)
            bst_report('Snapshot',hFigMri16,[],'Sensor-MRI registration back view', [200,200,750,475]);
            % Close figures
            close(hFigMri16);
            
            % View sources on Scalp
            [sSubject, iSubject] = bst_get('Subject', subID);
            
            MriFile        = sSubject.Anatomy(sSubject.iAnatomy).FileName;
            ScalpFile      = sSubject.Surface(sSubject.iScalp).FileName;
            
            hFigMri20      = script_view_surface(ScalpFile, [], [], [],'front');
            hFigMri20      = view_channels(ChannelFile, 'EEG', 1, 0, hFigMri20, 1);
            bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration front view', [200,200,750,475]);
            savefig( hFigMri20,fullfile(subject_report_path,'Sensor-Scalp registration front view.fig'));
            %Left
            view(1,180)
            bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration left view', [200,200,750,475]);
            % Right
            view(0,360)
            bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration right view', [200,200,750,475]);
            % Back
            view(90,360)
            bst_report('Snapshot',hFigMri20,[],'Sensor-Scalp registration back view', [200,200,750,475]);
            % Close figures
            close(hFigMri20);
            
            %%
            %% Process: Import Atlas
            %%
            [sSubject, iSubject] = bst_get('Subject', subID);
            
            %
            LabelFile = {Atlas_seg_location,'MRI-MASK-MNI'};
            script_import_label(sSubject.Surface(sSubject.iCortex).FileName,LabelFile,0);
            
            %%
            %% Quality control
            %%
            %
            hFigSurf24 = view_surface(CortexFile);
            % Deleting the Atlas Labels and Countour from Cortex
            delete(findobj(hFigSurf24, 'Tag', 'ScoutLabel'));
            delete(findobj(hFigSurf24, 'Tag', 'ScoutMarker'));            
            delete(findobj(hFigSurf24, 'Tag', 'ScoutContour'));
            
            bst_report('Snapshot',hFigSurf24,[],'surface view', [200,200,750,475]);
            savefig( hFigSurf24,fullfile(subject_report_path,'Surface view.fig'));
            %Left
            view(1,180)
            bst_report('Snapshot',hFigSurf24,[],'Surface left view', [200,200,750,475]);
            % Bottom
            view(90,270)
            bst_report('Snapshot',hFigSurf24,[],'Surface bottom view', [200,200,750,475]);
            % Rigth
            view(0,360)
            bst_report('Snapshot',hFigSurf24,[],'Surface right view', [200,200,750,475]);
            % Closing figure
            close(hFigSurf24)            
            
            %%
            %% Getting Headmodeler options
            %%
            headmodel_options = get_headmodeler_options(modality, subID, iStudy);
                        
            %%
            %% Process: OpenMEEG
            %%
            [headmodel_options, errMessage] = bst_headmodeler(headmodel_options);
            
            if(~isempty(headmodel_options))
                sStudy = bst_get('Study', iStudy);
                % If a new head model is available
                sHeadModel = db_template('headmodel');
                sHeadModel.FileName      = file_short(headmodel_options.HeadModelFile);
                sHeadModel.Comment       = headmodel_options.Comment;
                sHeadModel.HeadModelType = headmodel_options.HeadModelType;
                % Update Study structure
                iHeadModel = length(sStudy.HeadModel) + 1;
                sStudy.HeadModel(iHeadModel) = sHeadModel;
                sStudy.iHeadModel = iHeadModel;
                sStudy.iChannel = length(sStudy.Channel);
                % Update DataBase
                bst_set('Study', iStudy, sStudy);
                db_save();
                
                %%
                %% Quality control of Head model
                %%
                qc_headmodel(headmodel_options,modality,subject_report_path)
                
                %%
                %% Save and display report
                %%
                ReportFile = bst_report('Save', sFiles);
                bst_report('Export',  ReportFile,report_name);
                bst_report('Open', ReportFile);
                bst_report('Close');
                processed = true;
                disp(strcat("-->> Process finished for subject: ", subID));
                
                Protocol_count = Protocol_count+1;
            else
                subjects_process_error = [subjects_process_error; subID];
                continue;
            end
%         catch
%             subjects_process_error = [subjects_process_error; subID];
%             [~, iSubject] = bst_get('Subject', subID);
%             db_delete_subjects( iSubject );
%             processed = false;
%             continue;
%         end
        %%
        %% Export Subject to BC-VARETA
        %%
        if(processed)
            disp(strcat('BC-V -->> Export subject:' , subject_name, ' to BC-VARETA structure'));
            if(selected_data_set.bcv_config.export)
                export_subject_BCV_structure(selected_data_set,subject_name);
            end
        end
        %%
        if( mod(Protocol_count,selected_data_set.protocol_subjet_count) == 0  || j == size(subjects,1))
            % Genering Manual QC file (need to check)
            %                     generate_MaQC_file();
        end
        disp(strcat('-->> Subject:' , subject_name, '. Processing finished.'));
        
    end
    disp(strcat('-->> Process finished....'));
    disp('=================================================================');
    disp('=================================================================');
    save report.mat subjects_processed subjects_process_error;
end
end

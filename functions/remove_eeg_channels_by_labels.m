function EEG = remove_eeg_channels_by_labels(user_labels, EEG)
if(isequal(EEG.nbchan,size(EEG.data,1)))
    data        = EEG.data;
    labels      = {EEG.chanlocs.labels}';
    from        = 1;
    limit       = size(data,1);
    while(from <= limit)
        pos = find(strcmpi(labels(from), user_labels), 1);
        if (isempty(pos))
            data(from,:)    = [];
            labels(from)    = [];
            limit           = limit - 1;
        else
            from = from + 1;
        end
    end
    EEG.data        = data;
    EEG.chanlocs(length(labels)+1:end,:) = [];
    [EEG.chanlocs.labels]    = labels{:};
    EEG.nbchan      = size(data,1);
else
    labels      = {EEG.chanlocs.labels}';
    from        = 1;
    limit       = size(labels,1);
    while(from <= limit)
        pos = find(strcmpi(labels(from), user_labels), 1);
        if (isempty(pos))            
            labels(from)    = [];
            limit           = limit - 1;
        else
            from = from + 1;
        end
    end
    EEG.chanlocs(length(labels)+1:end,:) = [];
    [EEG.chanlocs.labels]    = labels{:};
    EEG.nbchan      = length(labels);
end
end

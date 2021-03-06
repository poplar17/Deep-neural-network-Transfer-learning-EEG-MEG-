%% dictionary of dataset and label
clc; clear;
dirname = 'H:\Sujit Roy\civ2vcnn\BCICIV_2b_gdf';
dirname2 ='H:\Sujit Roy\civ2vcnn\true_labels';

%%%%%% get data of each subject
XTrain = [];
YTrain = [];
categ =[];
nn = 0;
mm = 0;
for kn=1:9
    p(kn) = 0; % get the number of none value
    sampleRate = 250; % sample frequency

    % to enrich data, set window size to 2 s with an overlap of 90%
    delayTime = 50;
    timeScale = 2;

    total_data_idx = 1; % combinitation of data from all session; for optimal frequency band selection
    for i = 1:5 % set 5 to also get evalution dataset
        if(i<4)
            dataName = ['B0',num2str(kn),'0',num2str(i),'T.gdf'];
            labelName = ['B0',num2str(kn),'0',num2str(i),'T.mat'];
        else
            dataName = ['B0',num2str(kn),'0',num2str(i),'E.gdf'];
            labelName = ['B0',num2str(kn),'0',num2str(i),'E.mat'];
        end
        [signal{i},H{i}] = mexSLOAD(fullfile(dirname,dataName));

        test_EVENT = H{i}.EVENT;
%         indx_trig = sort([find(test_EVENT.TYP==769);find(test_EVENT.TYP==770)]);
        indx_trig = sort(find(test_EVENT.TYP==768));
        H{i}.TRIG = H{i}.EVENT.POS(indx_trig);

        load(fullfile(dirname2,labelName));
        trueLabels{i}= classlabel;

        % get the label of each segments
        CIV2b_S{kn}.D{i}.raw = signal{i}(:,1:3); % original signals from c3,c4 and cz
        trial = length(H{i}.TRIG);

        CIV2b_S{kn}.D{i}.labels = trueLabels{i}; % get label

        n = 1;
        for j = 1:trial % extract MI signals from 3-7s
            meanValue = mean( CIV2b_S{kn}.D{i}.raw(H{i}.TRIG(j) : H{i}.TRIG(j) + sampleRate*2 ,:));
            if( any( any( isnan( CIV2b_S{kn}.D{i}.raw( H{i}.TRIG(j) : H{i}.TRIG(j) + sampleRate*7 ,: ) ) ) ) )
                p(kn) = p(kn) + 1;
                continue;
            end
            temp = CIV2b_S{kn}.D{i}.raw( H{i}.TRIG(j) + sampleRate*3 : H{i}.TRIG(j) + sampleRate*7 ,: );
            CIV2b_S{kn}.D{i}.MI{j}= [temp(:,1) - meanValue(1),temp(:,2) - meanValue(2),temp(:,3) - meanValue(3)];
            m = 0;
            while ( m*delayTime <= 500) % get the 2s length segment
                CIV2b_S{kn}.D{i}.tra{n}.data{m+1} =  CIV2b_S{kn}.D{i}.MI{j}(m * delayTime + 1 : m * delayTime + timeScale * sampleRate,:);
                CIV2b_S{kn}.D{i}.tra{n}.labels{m+1} =  CIV2b_S{kn}.D{i}.labels(j);

                % data combination
                CIV2b_S{kn}.all_data{total_data_idx} = CIV2b_S{kn}.D{i}.tra{n}.data{m+1};
                CIV2b_S{kn}.all_data_label(total_data_idx) = CIV2b_S{kn}.D{i}.tra{n}.labels{m+1};
                total_data_idx = total_data_idx + 1;

                m = m+1;
            end
            CIV2b_S{kn}.D{i}.Labels(n) = CIV2b_S{kn}.D{i}.labels(j);
            n = n+1;
        end
    end


    for sess = 1:5 % 5 for contains evaluation session

        CIV2b_Data_S{kn}.se{sess}.Labels = CIV2b_S{kn}.D{sess}.labels;

        muBand = [4,13];
        betaBand = [13,32];

        % get the all input images and labelsof CNN
        for i = 1 : length(CIV2b_S{kn}.D{sess}.tra)
            for kk = 1:length(CIV2b_S{kn}.D{sess}.tra{i}.data)
                for j = 1:3
                    Cx{j} = CIV2b_S{kn}.D{sess}.tra{i}.data{kk}(:,j);

                    % short time Fourier transform
                    [Fstft, f, t] = stft(Cx{j}, 64, 14, 512, 250);
                    Mu{j} = abs( Fstft( (find(f<muBand(1),1,'last') ) : (find(f<muBand(2),1,'last')) +1 ,:) );
                    Beta = abs( Fstft( (find(f<betaBand(1),1,'last') ) : (find(f<betaBand(2),1,'last')) +1,: ) );

                    % beta band cubic interpolation
                    interNum = size(Mu{j},1);
                    fBeta = betaBand(1) : (betaBand(2)-betaBand(1))/(interNum-1) : betaBand(2);
                    [X,Y] = meshgrid(t,f);
                    [X1,Y1] = meshgrid(t,fBeta);
                    Beta_intrp{j} = interp2( X,Y,abs( Fstft ),X1,Y1,'cubic');

                    % normalization
                    Mu{j} = NorValue(Mu{j},1);
                    Beta_intrp{j} = NorValue(Beta_intrp{j}, 1);
                end

                CIV2b_Data_S{kn}.se{sess}.tra{i}.C3{kk} = [Beta_intrp{1}; Mu{1}];
                CIV2b_Data_S{kn}.se{sess}.tra{i}.Cz{kk} = [Beta_intrp{2}; Mu{2}];
                CIV2b_Data_S{kn}.se{sess}.tra{i}.C4{kk} = [Beta_intrp{3}; Mu{3}];

                CIV2b_Data_S{kn}.se{sess}.tra{i}.image{kk} =  cat(3, CIV2b_Data_S{kn}.se{sess}.tra{i}.C4{kk}, CIV2b_Data_S{kn}.se{sess}.tra{i}.Cz{kk}, CIV2b_Data_S{kn}.se{sess}.tra{i}.C3{kk});
                switch CIV2b_S{kn}.D{sess}.tra{i}.labels{kk} % for each label
                    case 1
                        CIV2b_Data_S{kn}.se{sess}.tra{i}.labels{kk} = 1;
                    case 2
                        CIV2b_Data_S{kn}.se{sess}.tra{i}.labels{kk} = 2;
                    otherwise
                        CIV2b_Data_S{kn}.se{sess}.tra{i}.labels{kk} = 3;
                end
            end
        end

        CIV2b_Data_S{kn}.band = [muBand,betaBand];
    end


%     XTrain = cell(1,1e4);
%     YTrain = cell(1,1e4);
%     n = 0;
%     m = 0;
    for sess = 1:5
        for i = 1 : length(CIV2b_S{kn}.D{sess}.tra)
            for kk = 1:length(CIV2b_S{kn}.D{sess}.tra{i}.data)
                nn = nn+1;
                XTrain(:,:,:,nn) = CIV2b_Data_S{kn}.se{sess}.tra{i}.image{kk};
%                 YTrain{n} = cell2mat(CIV2b_Data_S{kn}.se{sess}.tra{i}.labels(kk));

%             m = m+1;
            YTrain(:,:,:,nn) = cell2mat(CIV2b_Data_S{kn}.se{sess}.tra{i}.labels(kk));
            subIndex(nn)=kn;
            end

        end
    end
[size(XTrain) size(YTrain)]

end
clearvars -EXCEPT XTrain YTrain kn subIndex

% size(XTrain)
%     XTrain = reshape(cell2mat(XTrain(1:nn)), size(XTrain{1},1), size(XTrain{1},2), size(XTrain{1},3), []);
%     YTrain = cell2mat(YTrain(1:nn));
%     fprintf('Size of Training data of subject %d \n', kn);
%     size(XTrain)
%     XTrainAll = cat(4,XTrainAll,XTrain);
%     fprintf('Size of Training data after addition of subject %d \n', kn);
%     size(XTrainAll)
%     YTrainAll = cat(2,YTrainAll,YTrain);
%     fprintf('Size of label data after addition of subject %d \n', kn);
%     size(YTrainAll)
%     categ = cat(2,categ, kn*ones(1,length(YTrain)));
YTrain=squeeze(YTrain);


%%%%%
% ind = randperm(length(YTrain));
% YTrainSuffle = YTrain(ind);
% XTrainSuffle = XTrain(:,:,:,ind);
% subIndexSuffle = subIndex(ind);
YTrainSuffle = YTrain;
XTrainSuffle = XTrain;
subIndexSuffle = subIndex;
clear XTrain YTrain subIndex
for kn = 6:9
    tic
    ss = (subIndexSuffle==kn);
    size(ss)
    Xte = XTrainSuffle(:,:,:,ss);
    fprintf('Size of test data of subject %d \n', kn);
    size(Xte)
    Yte = YTrainSuffle(ss);
    fprintf('Size of test label of subject %d \n', kn);
    size(Yte)
    Xtr = XTrainSuffle(:,:,:,~ss);
    fprintf('Size of train data of all subject %d \n', kn);
    size(Xtr)
    Ytr = YTrainSuffle(~ss);
    fprintf('Size of train label of all subject %d \n', kn);
    size(Ytr)
    rng(1)
%     Ytr = categorical(Ytr);
%     Yte = categorical(Yte);


    %%
    optimVars = [
        optimizableVariable('SectionDepth',[1 5],'Type','integer')
        optimizableVariable('InitialLearnRate',[1e-6 1e-2],'Transform','log')
        optimizableVariable('L2Regularization',[1e-10 1e-2],'Transform','log')];
    ObjFcn = makeObjFcn(Xtr,categorical(Ytr),Xte,categorical(Yte));
    BayesObject = bayesopt(ObjFcn,optimVars, ...
        'MaxTime',14*60*60, ...
        'IsObjectiveDeterministic',false, ...
        'UseParallel',true);
    bestIdx = BayesObject.IndexOfMinimumTrace(end);
    VE = BayesObject.UserDataTrace{bestIdx};
    savedStruct(kn) = load(VE);
    valError = savedStruct(kn).valError
    [YPredicted,probs] = classify(savedStruct(kn).trainedNet,Xte);

    seq = reshape(double(YPredicted)-1, 11, []);
    seq = sum(seq);
    seq = double((seq>5));
    seqtarget = (Yte(1:11:end)-1)';

    seqprob = reshape(probs(:,2)-probs(:,1), 11, []);
    seqprob = sum(seqprob);
    seqprob = double((seqprob>0));
    acc_prob(kn) = mean(seqprob == seqtarget);


    kk1 = ((seq == 1) & (seqtarget == 1));
    kk0 = ((seq == 0) & (seqtarget == 0));

    a = nnz(((seq == 0) & (seqtarget == 0)));
    d = nnz(((seq == 1) & (seqtarget == 1)));
    b = nnz(((seq == 0) & (seqtarget == 1)));
    c = nnz(((seq == 1) & (seqtarget == 0)));
    total = (a+b+c+d);
    po(kn) = ((a+d)/total);
    pyes = ((a+b)/total)*((a+c)/total);
    pno = ((c+d)/total)* ((b+d)/total);
    pe = pyes + pno;
    kappa(kn) = (po(kn) -pe)/(1-pe);




%     testError(kn) = 1 - mean(YPredicted == Yte);
    accuracy(kn) = sum ((YPredicted) == categorical(Yte))/numel(Yte);
%     NTest = numel(Yte);
%     testErrorSE = sqrt(testError(kn)*(1-testError(kn))/NTest);
%     testError95CI = [testError(kn) - 1.96*testErrorSE, testError(kn) + 1.96*testErrorSE]

%     figure('Units','normalized','Position',[0.2 0.2 0.4 0.4]);
%     cm(kn) = confusionchart(Yte,YPredicted);
%     cm(kn).Title = (['Confusion Matrix for Test Data for subject ', num2str(kn)]);
%     cm(kn).ColumnSummary = 'column-normalized';
%     cm(kn).RowSummary = 'row-normalized';
    toc
    %%

    clear Xtr Xte Ytr Yte seqprob seqtarget ss Ypredicted pe pyes pno kk1 kk0
end
mean_accuracy = mean(accuracy);
%

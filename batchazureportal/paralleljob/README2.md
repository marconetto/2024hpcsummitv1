## 3. Run an embarassingly parallel job: Convert mp4 to mp3 files using ffmpeg application

   ## Create a storage account

   1. In Azure portal, go to Home.
   2. Search for storage accounts, and create new.
   3. Use the resource group created in the previous section.
   4. Name the new account as "yourinitials"hpcbatchdemostorageaccnt.
   5. Keep rest of the properties as default
   6. Review + create
  
## Add containers to the Azure Storage
   1. Go to newly created storage account
   2. Add two containers named, "input" and "output" to the storage account
   3. Copy the files from [here](https://github.com/Azure-Samples/batch-python-ffmpeg-tutorial/tree/master/src/InputFiles) to the "input" container
         - Download the files locally first and upload them into the input container

## Link Azure storage and batch accounts
            
1. Go to the batch account.
2. Select Storage account from laeft side navigation pane and click on select a storage account.
3. Select the storage account you created and click save.

   
Go to storage account page. Navigate to the Access Keys from the left navigation pane. Copy the storage account name and 'Key1' key. Keep them handy for the next part. 


### Create a Job and parallel tasks
   1. Go to the batch accoutn and Create a job. name it as "yourinitials"-ffmpegdemo.
   2. Add a task in the job, and name it as task1.
   3. Enter the command in command line as given below (replace the storage account and storage account key)

```
/bin/bash -c "inputfile=LowPriVMs-1.mp4 outputfile=LowPriVMs-1.mp3 \
mystorageaccount=YOUR_STORAGE_ACCOUNT \
key=STORAGE_ACOOUNT_KEY && \
ffmpeg -i $inputfile $outputfile && \
sleep 30 && \
az storage blob upload --account-name $mystorageaccount --account-key $key --container-name output --file $HOME/$outputfile --name $outputfile --overwrite"
```

**This commands uses ffmpeg to process the input mp4 file and generate the output mp3 file. The output file is saved in the home directory. It is then uploaded to the output container using  az storage blob upload command.**

4. Select 'Task autouser, Admin' in Elevation Level
5. Click on Resource Files. 
6. Select "Pick Storage Blob". Check the "Include SAS" checkbox and click OK.
7. Search for the storage account you created earlier, select the "input" container and choose the file "LowPriVMs-1.mp4"
8. Click Submit
9. Submit the task.
10. Monitor the task progress by clicking on the task name on job page. 
11. Repeat the above steps for other files in the Input container. 


## 3. Run an embarassingly parallel job: Convert mp4 to mp3 files using ffmpeg application

1. Create a job and name it as "yourinitials"-ffmpegdemo 
2. Add a task in the job, and name it as task1
3. Enter the command in command line as given below (replace the storage account and storage account key)

```
/bin/bash -c "inputfile=LowPriVMs-2.mp4 outputfile=LowPriVMs-2.mp3 \
mystorageaccount=YOUR_STORAGE_ACCOUNT \
key=STORAGE_ACOOUNT_KEY && \
ffmpeg -i $inputfile $outputfile && \
sleep 30 && \
az storage blob upload --account-name $mystorageaccount --account-key $key --container-name mycontainer --file $HOME/$outputfile --name $outputfile --overwrite"
```

This commands uses ffmpeg to process the input mp4 file and generate the output mp3 file. The output file is saved in the home directory. The output file is then uploaded to the output container using the az storage blob upload command.  

4. Select 'Task autouser, Admin' in Elevation Level
5. Click on Resource Files. 
6. Select "Pick Storage Blob" and search for the storage account you created earlier, select the Input container and choose the file "LowPriVMs-1.mp4"
7. Click Submit
8. Submit the task.
9. Monitor the task progress by clicking on the task name on job page. 
10. Repeat the above steps for other files in the Input container. 


using System;
using System.IO;
using System.Linq;
using ZL176.Properties;
using System.Data;

/*#Region "Boilerplate"
' PROGRAM NAME:   Program.cs
' SOURCE FILE:    ZL176.sln
'
' PROGRAMMER(S):  JNB
' DATE:           2018

' DESCRIPTION:    Reads and moves pdf file names and writes each file name to create a csv for system index.
'                 app.config setup to pull files from \\server\pdfs\Data\Ready_for_Export and move them to another server.
'                 From our server, run ZL176W02 to SFTP the files over to VENDOR. 
' 
' REVISIONS:
' Nathanial Barton     October 2018 - Used loops to limit the amount of files read and moved due to volume of storage space available.
*/

namespace ZL176
{
    class Program
    {
        static void Main(string[] args)
        {
            var folder = Settings.Default["folder"].ToString();
            var folderString = Settings.Default["folderString"].ToString();
            var uploadFolder = Settings.Default["uploadFolder"].ToString();
            var uploadFolderString = Settings.Default["uploadFolderString"].ToString();

            //create csv file
            String path = @folderString + "SYSTEM_ZL176" + "_" + DateTime.Now.ToFileTime() + ".csv" ;
            StreamWriter csv = new StreamWriter(path);
            String linet = "Date01, Date02, Filter01, Group_ID, Customer_ID, FileName"; // column headers
            csv.WriteLine(linet);

            var files = from file in Directory.GetFiles(folder, "*.OUT")
                        .Select(file => Path.GetFileName(file))
                        orderby file descending
                        select file;
            
            foreach (string myfile in files)
            {
                string filename = myfile;
                System.IO.File.Move(myfile, filename);
            }

            files = from file in Directory.GetFiles(folder, "*.pdf")
                    .Select(file => Path.GetFileName(file))
                    orderby file descending
                    select file;

            var i = 0;                  // loop var
            foreach (string file in files)
            {
                i++;                     // loop var incrementer
                if (i > 40000) break;    // loop for amount of files to read
                string fileName = file.Replace(folderString, string.Empty);
                string data = string.Empty;

                {
                    data = fileName;

                    string pdfs = data.Replace(" ", "_");

                    string[] pdfInfo = pdfs.Split('_');
                    Array.Reverse(pdfInfo);

                    DateTime date = DateTime.Now;
                    string fName = Path.GetFileName(file);
                    string customerID = pdfInfo[0].Trim('.','p','d','f');
                    string groupID = pdfInfo[1].Trim();
                    string filter01 = string.Empty;

                    // Determine letter type for Filter01 column.
                    string letterType = pdfInfo.Last().Trim();
                    if (letterType == "OFF" || letterType == "Off" || letterType == "ON" ||  letterType == "Cars" || letterType == "65" || letterType == "MAX*")
                    {
                        filter01 = "Discontinuation Letter";
                    }

                    else if (letterType == "MASS-1099")
                    {
                        filter01 = "MASS-1099";
                    }

                    else if (letterType == "MASS-1099-GA")
                    {
                        filter01 = "MASS-1099-GA";
                    }

                    else if (letterType == "ACK")
                    {
                        filter01 = "Daily Acknowledgement Letters";
                    }

                    else if (letterType == "ANN")
                    {
                        filter01 = "Year End Acct Bal";
                    }

                    else
                    {
                        filter01 = "Unknown Letter Type";
                    }

                    linet = string.Format("{0},{1},{2},{3},{4},{5}", (FormatDate(date)),
                    "2019 january 1", filter01 , groupID, customerID,
                    fName, Environment.NewLine);

                    csv.WriteLine(linet);

                }                
            }

            files = from file in Directory.GetFiles(folder, "*.pdf")
                    orderby file descending
                    select file;

            csv.Close();
            MovePdfs();
            MoveCsv();
        }

        private static string FormatDate(DateTime date)
        {
            return String.Format("{0}{1}", date.ToString("yyyy "), date.ToString("M"));
        }

        private static void MovePdfs()
        {
            var folder = Settings.Default["folder"].ToString();
            var folderString = Settings.Default["folderString"].ToString();
            var uploadFolderString = Settings.Default["uploadFolderString"].ToString();

            var files = from file in Directory.GetFiles(folder, "*.pdf")
                        orderby file descending
                        select file;

            var i = 0;                 // loop var
            foreach (string file in files)
            {
                i++;                   // loop var incrementer
                if (i > 40000) break;    // loop for amount of files to move
                string newFileNAme = file.Replace(folderString, uploadFolderString);
                File.Move(file, newFileNAme);
            }
            /*  // Commenting this loop out because it copies every pdf file. Storage issues sometimes arise, so we limit the amount of files moved.
            foreach (string file in files)
                        {
                            string newFileNAme = file.Replace(folderString, uploadFolderString);
                            File.Copy(file, newFileNAme, true);
                        }
            */
        }

        private static void MoveCsv()
        {
            var folder = Settings.Default["folder"].ToString();
            var folderString = Settings.Default["folderString"].ToString();
            var uploadFolderString = Settings.Default["uploadFolderString"].ToString();

            var files = from file in Directory.GetFiles(folder, "*.csv")
                        orderby file descending
                        select file;

            foreach (string file in files)
            {
                string newFileNAme = file.Replace(folderString, uploadFolderString);

                File.Move(file, newFileNAme);
            }
        }
    }
}

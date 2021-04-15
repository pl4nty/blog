---
title: "Microsoft Teams as an LMS"
date: 2021-02-14
draft: false
tags: ["webdev", "edu", "microsoft"]
---
# Prologue
With Queensland adopting the ATAR assessment system, digital assessment storage was one of many new requirements to tackle. We were lagging behind other schools with no existing LMS, but this was a blessing in disguise - we weren’t locked into a non-compliant vendor.

Time was running out, so Microsoft Teams was chosen to become a short-term repository/learning management system. Nothing is cheaper than free (so I was told), and the SharePoint backend would be easy to migrate if/when needed.

Using Teams as a stop-gap hasn’t been without its challenges. We expected slimmed-down features for a relatively new (and free) product. But like other modern Microsoft products, it seems we’ve become their QA department. It's something that’s ok for IT to stomach, but unhelpful for production users.

Here’s some of the challenges I overcame, enjoy.

# Act 1: Thicc Files
Teams has an arbitrary 10MB file size limit on assessment submissions, but the SharePoint and Teams Graph APIs don’t reflect this. So using the Teams React components I built a simple SSOed website to upload a file to a chosen assignment.

The Teams team (haha) are migrating to Fabric UI, but I was new to React so used [the first result on Google](https://github.com/OfficeDev/msteams-ui-components). If I was doing this again, I'd also use Yeoman to generate boilerplate - thanks to the Microsoft 365 Bootcamp for showing me this best practice, even if it was too late.

[The API endpoints](https://docs.microsoft.com/en-us/graph/api/resources/education-overview?view=graph-rest-beta) were pretty simple, even though they’re in beta. Just a couple of list calls for classes and assessments, then upload the file to the corresponding SharePoint folder and link it to the Teams assessment. Simple!

Only a few weeks later, unofficial support for large files was added to Teams. It still throws an error when linking to the assessment item, but the file does actually upload to SharePoint. Anyway, it was a fun intro to React, so I can’t complain.

### June Edit
It was just a prank, Microsoft removed the file upload and even one of the endpoints I was using. Move fast and break things, right guys?

So I rewrote it as a Teams app with Yeoman, Fabric, and my newly-acquired React skillz.
While I was away the Fabric migration was finished, so I added progress bars, file type icons, and multi-file/cancellable uploads.

SSO tokens were recently added too, so I wrote some API middleware to exchange them for access tokens and achieved silent SSO!
The final touch was a GitHub Action for continuous deployment, written on my own time so [it's open source](https://github.com/pl4nty/teams-deploy-tab).

# Act 2: Printing (Oh, the Horror!)
So Teams is fine and dandy for digital assessment, but what about those pesky written exams? Time to dive into the world of document management systems. Dozens of vendors threw poorly-made (or non-functioning) products at us, so we decided to create, scan and store written assessment ourselves.

It all started with printing. We went with a manual document generation approach to handle our CRM's CSV output, ending up with a QR-coded Word template. A handy Adobe add-in spat out mail-merged cover pages, that were merged onto exam PDFs with an Adobe Acrobat script. Ugly I know, but the process was quick to develop and supported all the familiar binding and collating options on our Xerox MFPs.

Next came scanning and sorting after the assessment. We went lightweight on vendor lock-in, using PaperCut to scan to a network location from our MFPs. ABBYY OCR read from there, renaming the files with their QR code metadata and uploading them to a SharePoint ingest site.

An Azure Logic App monitored the site, parsing the metadata and uploading to the corresponding SharePoint locations created by Teams (and removed student access). The Logic App's service account had to own every SharePoint site, scripted with Azure Automation runbooks, but it was a small price to pay.

Hopefully Teams will support creating assignments with service accounts soon, so students could check their work, but for now at least the files are stored. Alternatively, maybe a custom app/site for teachers to click “release assessment”? But as with all things IT, it’s a matter of priorities.

# Epilogue
I hope you enjoyed this glimpse into the education space. Please reach out if you have advice for this amateur developer, or would like me to elaborate on anything. Bye for now!

### 2021 Edit
I've since finished working in education, but still have plenty of spicy stories to tell. Maybe they'll grace the pages of this blog some day... For now, I'm going back to the CTF grind. See ya!
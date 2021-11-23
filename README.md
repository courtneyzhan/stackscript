# Deployment Stackscript
Simple and flexible set of stackscripts created and used to set up a server for cloud platforms (e.g. Linode, Vultr and maybe AWS & Azure).  

For all of the scripts in this repo, a log is written to `/root/stackscript.log`. To monitor any of these scripts while running, use the following command:  

`tail -f /root/stackscript.log`

### Rails
The stackscript I did use for setting up and deploying [this basic sample Rails6 project](https://github.com/courtneyzhan/sample-rails6-bootstrap5) (hosted on Vultr).  

This script installs and uses gcc, MySQL, Sqlite3, NodeJS, Nginx and Ruby on Rails; clones the repository and sets it up with Nginx and Passenger.

Takes just over 6 minutes to complete.
#### Notes
The user password (line 6: DEPLOY\_PASSWORD) should be changed to a suitable Linux approved password.  
The project is run in development mode (line 144, 145), to run in production, change the RAILS_ENV variable in those lines.
# README #

ssbackup.sh and ssrestore.sh are two scripts designed to facilitate the process of updating WordPress web sites.

As you may already know, updating a WordPress site can be a tedious task rife with errors, especially if you use poorly written plugins or themes (we all cave to the pressure sometimes). Using these two scripts you can easily backup and restore WordPress sites should the update fail.

# IMPORTANT #
The scripts assume a few things that, if not totally kosher, may have unexpected consequences. This is what the script assumes:

1. The user you log in as has write access to the directory above the DOCUMENT_ROOT. So, for example, if you're on a shared host logged in as your own user, you can probably write files to ~/SecretSourceBackups. This is sufficient access.
2. You will run the script from the directory just above your DOCUMENT_ROOT. So, if you log in to your account via SSH on a share host, you'll run the scripts from a directory that has a subfolder called "public_html".
3. You are NOT doing multisite WordPress (maybe I'll write something for that some day…)

# An Example #

We are going to update the fictitious site fancywidgets.com. Fancywidgets.com is a WooCommerce store with a blog and all kinds of social plugins and masonry galleries and every manner of hook and theme modification you can imagine. The update is going to fail…

For this example we assume these two scripts are installed on the server (probably in /usr/local/bin, but could be anywhere a normal users can run them).

These are the steps we follow to update a site:
1. Log on to the server via SSH
2. Navigate to the directory just above your DOCUMENT_ROOT. On a shared server you probably won't have do to anything as the default is to land in your home directory, which usually has public_html as a subdirectory.
3. Run ssbackup.sh. The script will create a complete backup of your database and site files.
4. Log in to the WordPress Admin and run the updaters.
5. Go to the front end of your web site and soak up the joy of open source software (including these scripts ;-)
6. From the command line, run ssrestore.sh. You'll see a list of backup files. Pick one, probably the most recent, and hit Enter to roll back.
7. Figure out how to fix all the broken pieces and do steps 3 through 6 ad infinitum.

If, for some reason, your DOCUMENT_ROOT is not called "public_html", you can change it with the flag --documentroot. So, the backup command would look like this:

```
ssbackup.sh --documentroot 'web'
```


### What is this repository for? ###

* Quick summary
* Version
* [Learn Markdown](https://bitbucket.org/tutorials/markdowndemo)

### How do I get set up? ###

* Summary of set up
* Configuration
* Dependencies
* Database configuration
* How to run tests
* Deployment instructions

### Contribution guidelines ###

* Writing tests
* Code review
* Other guidelines

### Who do I talk to? ###

* Repo owner or admin
* Other community or team contact
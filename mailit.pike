//
// This is a Roxen module.
//
// Written by Bill Welliver, <hww3@riverweb.com>
//
//
string cvs_version = "$Id: mailit.pike,v 1.5 1999-06-20 19:14:42 hww3 Exp $";
#include <module.h>
#include <process.h>
inherit "module";
inherit "roxenlib";

array register_module()
{
  return ({ MODULE_PARSER,
            "MailIt! 1.0  Module",
            "Adds the container 'mailit' and the tag 'mfield'.", ({}), 1
            });
}

void create()
{
  defvar("sendmail", "/usr/lib/sendmail", "Sendmail Binary", 
         TYPE_STRING,
         "This is the location of the sendmail binary.\n");
 defvar("checkowner", 1, "Send mail from owner of template file",
	TYPE_FLAG,
         "If set, and Roxen is running as a sendmail trusted user,"
	 " MailIt! will send the mail as the owner of the template file.");
 defvar("mailitdebug", 0, "Enable debugging",
	TYPE_FLAG,
         "If set, MailIt! will write debugging information to the error log."
	 );

}

string|void check_variable(string variable, mixed set_to)
{
        if (variable=="sendmail")
                {
		if(!file_stat(set_to))
		return "File doesn't exist!";
                }
}

string tag_header(string tag_name, mapping arguments,
		object request_id, object file, mapping defines)
  {

  string headtype;
  string headvalue;

  if (arguments->subject)
    {
    headtype="Subject";
    headvalue=arguments->subject;
    }
  else if (arguments->to)
    {
    headtype="To";
    headvalue=arguments->to;
    }
  else if(arguments->name && arguments->name!="")
    {
    headtype=arguments->name;
    headvalue=arguments->value||"";
    }
  else return "<!-- Skipping header tag because of incorrect usage. -->";
perror("parsing header: "+headtype+" "+headvalue+"\n");

  request_id->misc->mailitmsg->headers+=([headtype:headvalue]);
  return "";

  }

string tag_mfield(string tag_name, mapping arguments,
		object request_id, object file, mapping defines)
	{
	string retval="";
	if(query("mailitdebug"))
		perror("MailIt!: Parsing mfield "+ arguments->name + "...\n");
	if(arguments->name)
		{
		if(request_id->variables[arguments->name] && (string)request_id->variables[arguments->name]!="")
			retval=request_id->variables[arguments->name];
		else if (arguments->empty)
			retval=arguments->empty;
		}
	if(arguments->add && (string)request_id->variables[arguments->name]!="")
		retval+=arguments->add;
	return retval;
	}


mixed container_message(string tag_name, mapping arguments,
			string contents, object request_id,
			mapping defines)
{

if (arguments->encoding)
request_id->misc->mailitmsg->setencoding(arguments->encoding);
else
request_id->misc->mailitmsg->setencoding("7bit");
if(arguments->preprocess){
/*
   object in=clone(Stdio.File, "stdout");
   object  out=in->pipe();
   object in2=clone(Stdio.File, "stdin");
   object  out2=in2->pipe();
perror("starting preprocessor...");   
spawn(arguments->preprocess,out,out2,out);
perror("done.\n");   
   in->write(contents);
perror("message written to preprocessor.\n");   
   in->close();  
perror("input closed.\n");   
   contents=in2->read();
perror("output from preprocessor done.\n");   
   in2->close();
perror("preprocessing done.\n");   
*/
perror(arguments->preprocess+" << EOF\n"+contents+"\nEOF\n");
contents=popen(arguments->preprocess+" << EOF\n"+contents+"\nEOF\n"); 
perror(contents);
  }

request_id->misc->mailitmsg->setdata(contents);
return "";

}

mixed container_mailit(string tag_name, mapping arguments,
			string contents, object request_id,
			mapping defines)
	{
	string retval="";
        request_id->misc+=(["mailitmsg":MIME.Message("",
  	  ([ "MIME-Version" : "1.0",
             "Content-Type" : "text/plain; charset="+(arguments->charset||"iso-8859-1"),
	     "X-Mailer" : "MailIt! for Roxen 1.2" ])
		) ]);

	contents=parse_rxml(contents, request_id);
	contents = parse_html(contents,([ "mailheader":tag_header ]),
                    (["mailmessage":container_message]), request_id ); 
	array(mixed) f_user;
	if(query("checkowner")){
		array(int) file_uid=file_stat(request_id->realfile);
		f_user=getpwuid(file_uid[5]);
		}

    object in=clone(Stdio.File, "stdout");
        object  out=in->pipe();
 
	if(query("mailitdebug")){
		if(query("checkowner"))
		perror("MailIt!: Sending mail from "+f_user[0]+"...\n");
		perror("MailIt!: Sending mail...\n");
		}
	if(query("checkowner")){
	  spawn(query("sendmail")+" -t -f "+f_user[0]+"",out,0,out);
	  }
	else {
	  spawn(query("sendmail")+" -t",out,0,out);
	  }
	retval=(string)request_id->misc->mailitmsg;
	in->write((string)request_id->misc->mailitmsg);
	in->close();
	m_delete(request_id->misc,"mailitmsg");		
//	return "<pre>"+retval+"</pre>";	
	return contents;
	}


mapping query_tag_callers() { return (["mfield":tag_mfield,]); }

mapping query_container_callers() { return (["mailit":container_mailit, ]); }








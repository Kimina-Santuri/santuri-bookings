-- Confirmed existing spaces. Opening DAYS are deliberately not invented.
-- Configure weekly hours in the staff dashboard before enabling bookings.
insert into public.spaces(slug,name,category,summary,description,features,tag,image_url,image_alt,calendly_url,allowance_kind,capacity,hourly_rate,sort_order) values
('studio','Recording Studio','sound','A maintained production room for recording, mixing and collaborative sessions.','A focused production and recording environment for turning an idea into a finished piece of audio.','Music production
Recording sessions
Mixing and mastering
Collaborative projects
Podcast and voice-over recording','Record · Produce · Mix','assets/images/studio-large.jpg','Santuri production and recording studio','https://calendly.com/studio-santuri/studio-bookings','studio',5,1000,0),
('dj','DJ Practice Room','sound','Dedicated time on a professional DJ setup, whether you’re learning or preparing a set.','Dedicated time and space to learn the equipment, develop transitions and prepare a set without distraction.','Pioneer CDJ setup
Traktor controller setup
Private practice sessions
Private lessons','Practice · Learn · Refine','assets/images/dj-room-large.jpg','Santuri DJ practice room with professional decks','https://calendly.com/djpractice-santuri/30min?primary_color=787878','none',3,1000,1),
('classroom','Classroom','group','A flexible group space for workshops, rehearsals, meetings and collaboration.','A flexible shared room for exchanging knowledge, developing ideas and bringing groups together.','Workshops and training
Group rehearsals
Community meetings
Creative collaboration','Teach · Meet · Rehearse','assets/images/classroom-large.webp','Santuri classroom set up for a group session','https://calendly.com/classroompractice-santuri/30min','none',20,1000,2),
('workstation','Creative Workstation','focus','A focused station for online work, music technology practice and electronics projects.','A focused desk for independent work, hands-on learning and smaller technical projects.','Online meetings
Personal gear practice
Self-paced synth learning
Email and document work
Electronics projects','Work · Learn · Build','assets/images/workstation-large2.jpg','Santuri workstation for focused creative work','https://calendly.com/santuriworkstations-santuri/30min','production',1,1000,3)
on conflict(slug) do nothing;

alter table public.onboarding_quiz_responses
  add column if not exists reminder_frequency text not null default 'No reminders';

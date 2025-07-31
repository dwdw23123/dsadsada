/*
  # Create votes table and trigger system

  1. New Tables
    - `votes`
      - `id` (uuid, primary key)
      - `candidate_name` (text, required)
      - `user_id` (uuid, foreign key to voters)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `votes` table
    - Add policies for public access to insert and select votes

  3. Constraints
    - Foreign key constraint linking votes to voters
    - Unique constraint on user_id to prevent duplicate voting

  4. Triggers
    - Auto-update voted_for column in voters table when vote is inserted

  5. Indexes
    - Performance indexes for common queries
*/

-- Create votes table
CREATE TABLE IF NOT EXISTS votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_name text NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Add foreign key constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'votes_user_id_fkey'
  ) THEN
    ALTER TABLE votes ADD CONSTRAINT votes_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES voters(id) ON DELETE CASCADE;
  END IF;
END $$;

-- Add unique constraint to prevent duplicate voting
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'unique_user_vote'
  ) THEN
    ALTER TABLE votes ADD CONSTRAINT unique_user_vote UNIQUE (user_id);
  END IF;
END $$;

-- Enable RLS
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Create policies for votes table
CREATE POLICY IF NOT EXISTS "Anyone can insert votes"
  ON votes
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Anyone can read votes"
  ON votes
  FOR SELECT
  TO public
  USING (true);

-- Create trigger function to update voted_for in voters table
CREATE OR REPLACE FUNCTION public.update_voter_voted_for()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.voters
  SET voted_for = NEW.candidate_name
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger
DROP TRIGGER IF EXISTS update_voter_voted_for_trigger ON votes;
CREATE TRIGGER update_voter_voted_for_trigger
  AFTER INSERT ON votes
  FOR EACH ROW EXECUTE FUNCTION update_voter_voted_for();

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_votes_user_id ON votes(user_id);
CREATE INDEX IF NOT EXISTS idx_votes_candidate_name ON votes(candidate_name);
CREATE INDEX IF NOT EXISTS idx_votes_created_at ON votes(created_at);
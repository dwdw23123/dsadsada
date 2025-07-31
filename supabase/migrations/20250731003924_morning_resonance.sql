/*
  # Create votes table and trigger

  1. New Tables
    - `votes`
      - `id` (uuid, primary key)
      - `candidate_name` (text, required)
      - `user_id` (uuid, foreign key to voters.id)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on `votes` table
    - Add policies for public access (insert, select)

  3. Constraints
    - Unique constraint on user_id to prevent duplicate votes
    - Foreign key constraint to voters table

  4. Trigger
    - Automatically update voters.voted_for when a vote is inserted
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

-- Add unique constraint to prevent duplicate votes
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints 
    WHERE constraint_name = 'votes_user_id_unique'
  ) THEN
    ALTER TABLE votes ADD CONSTRAINT votes_user_id_unique UNIQUE (user_id);
  END IF;
END $$;

-- Enable RLS
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- Create policies for public access
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

-- Create function to update voters.voted_for when a vote is inserted
CREATE OR REPLACE FUNCTION update_voter_choice()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE voters 
  SET voted_for = NEW.candidate_name 
  WHERE id = NEW.user_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_update_voter_choice ON votes;
CREATE TRIGGER trigger_update_voter_choice
  AFTER INSERT ON votes
  FOR EACH ROW
  EXECUTE FUNCTION update_voter_choice();

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_votes_user_id ON votes (user_id);
CREATE INDEX IF NOT EXISTS idx_votes_candidate_name ON votes (candidate_name);
module Personalization
  class ExperimentAssignment
    class << self
      def assign_variant(experiment_key:, user_id: nil, session_id: nil, force_variant: nil)
        return force_variant if force_variant.present?
        
        experiment = Experiment.find_by(key: experiment_key, status: 'running')
        return 'control' unless experiment
        
        subject = user_id || session_id
        return 'control' unless subject
        
        # Check for existing assignment
        assignment = find_assignment(experiment, user_id, session_id)
        return assignment.variant if assignment
        
        # Create new assignment
        variant = determine_variant(experiment, subject)
        create_assignment(experiment, user_id, session_id, variant)
        
        variant
      end
      
      def get_assignment(experiment_key:, user_id: nil, session_id: nil)
        experiment = Experiment.find_by(key: experiment_key)
        return nil unless experiment
        
        find_assignment(experiment, user_id, session_id)
      end
      
      private
      
      def find_assignment(experiment, user_id, session_id)
        if user_id.present?
          ExperimentAssignment.find_by(experiment: experiment, user_id: user_id)
        else
          ExperimentAssignment.find_by(experiment: experiment, session_id: session_id)
        end
      end
      
      def determine_variant(experiment, subject)
        # Deterministic hashing ensures sticky assignment
        hash_value = Digest::SHA256.hexdigest("#{experiment.key}:#{subject}")
        hash_int = hash_value.to_i(16)
        
        # Assign based on traffic percentage
        if (hash_int % 100) < experiment.traffic_pct
          'operator'
        else
          'control'
        end
      end
      
      def create_assignment(experiment, user_id, session_id, variant)
        ExperimentAssignment.create!(
          experiment: experiment,
          user_id: user_id,
          session_id: session_id,
          variant: variant
        )
      rescue ActiveRecord::RecordNotUnique
        # Race condition - assignment was created by another request
        # Return the existing assignment
        find_assignment(experiment, user_id, session_id)
      end
    end
  end
end

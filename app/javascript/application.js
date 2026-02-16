import "@hotwired/turbo-rails"
import { Application } from "@hotwired/stimulus"
import WorkspaceController from "controllers/workspace_controller"
import TranscriptionDisplayController from "controllers/transcription_display_controller"
import AudioCaptureController from "controllers/audio_capture_controller"

const application = Application.start()
application.register("workspace", WorkspaceController)
application.register("transcription-display", TranscriptionDisplayController)
application.register("audio-capture", AudioCaptureController)

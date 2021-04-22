export GCP_REGION="europe-west2"
export GCP_PROJECT_ID="auto-yfinance"
PATH_SA_KEY=`readlink -f env/sa.json`
export GOOGLE_APPLICATION_CREDENTIALS=$PATH_SA_KEY

gcloud config set project ${GCP_PROJECT_ID}
gcloud config set functions/region ${GCP_REGION}
gcloud services enable \
    iamcredentials.googleapis.com \
    cloudfunctions.googleapis.com \
    cloudbuild.googleapis.com

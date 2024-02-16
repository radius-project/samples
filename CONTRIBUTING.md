# Contributing Pull Requests

## What to work on

We welcome small pull request contributions from anyone (docs improvements, bug fixes, minor features.) as long as they follow a few guidelines:

- For very minor changes like correcting a typo feel free to just send a pull request without any ceremony. Otherwise ... 
- Please start by [choosing an existing issue](https://github.com/radius-project/samples/issues), or [opening an issue](https://github.com/radius-project/samples/issues/new/choose) to work on.
- The maintainers will respond to your issue, please work with the maintainers to ensure that what you're doing is in scope for the project before writing any code.
- If you have any doubt whether a contribution would be valuable, feel free to ask.

We the maintainers have discretion over what features and pull requests we accept. Please understand that we are responsible for the long-term support and maintenance of Radius, and so we sometimes need to make hard decisions to limit the scope. For another perspective on this, we really like this [article](https://www.igvita.com/2011/12/19/dont-push-your-pull-requests/).

## Sending a pull request

Please submit pull requests using a forked repo and open pull requests against:

- The default, versioned branch (`v0.30` for example) if you are adding/fixing a sample and it is compatible with the latest release of Radius.
- The `edge` branch if you are contributing a sample that requires a feature that will be available in the next release of Radius.

When opening a pull request, the form will be pre-populated with our template. Please fill out the template to provide structure to your PR message. If you've already written a good commit message (see below) it will be easy to use with our template.

A pull request will need to pass the following checkpoints to be accepted:

- Initial review: a maintainer will review your summary and make sure an appropriate issue is linked
- Testing: automated tests will run against your changes
- Code review: you will get feedback from a maintainer or other contributors in the form of comments

## Writing a good commit message

We value good commit messages that are descriptive and meaningful at a glance. A good format to follow is like the following:

```txt
<short description>

Fixes: #<issue>

<a longer description that includes>

- a summary of the changes being made
- the rationale for the change
- (optional) anything tricky or difficult as a heads up for reviewers
- (optional) additional follow up work that should be done (with links)
```

We **squash** pull-requests as part of the merge process, which means that intermediate commits will have their messages appended. We prefer to have a single commit in the git history for each PR.

## Code review

The maintainers or other contributors will add comments to your pull request giving feedback, asking questions, and making suggestions. Please respond to these comments to either continue the discussion or explain whether or not you plan to address the feedback. Ultimately, accepting a pull request is at the maintainer's discretion.

### Being proactive 

It can be helpful for you to comment on your own PR to point out relevant locations, decisions, opportunities for feedback, and tricky parts. This will help reviewers focus their attention as well as save them time.

### Resolving Feedback

You can "resolve" comments on your pull request when you've addressed the feedback: either through discussion or through making a code change. As the contributor of the pull-request feel free to mark comments as resolved when you feel like you've done a reasonable job addressing the feedback.

If you are the code reviewer, it's your responsibility to follow up (politely) if you feel your feedback has not been addressed adequately.

### Participating in code review

We welcome **any contributor or community member** to engage with **any pull request** on our repository. Feel free to make suggestions for improvements and ask questions that are relevant. If you're asking questions for your learning, please make it clear that your questions are "non-blocking" for the pull request.

See the [code reviewing documentation](../contributing-code/contributing-code-reviewing/README.md) for guidance on code reviewing.

## Inactive Pull Requests

Pull requests that have been inactive for 90 days will be marked with a stale label. They will automatically be closed after a subsequent 7 days of inactivity. This timeframe may be adjusted in the future based on project needs.